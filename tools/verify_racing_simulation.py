"""Cross-language regression against the captured JavaScript, at every 120Hz step."""
import json
import subprocess
from pathlib import Path
from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
MODULES = ROOT / "unity/Assets/RacingClone/Lua/Modules"
runtime = LuaRuntime(unpack_returned_tuples=True)
runtime.execute("package.path = " + json.dumps(str(MODULES / "?.lua")) + " .. ';' .. package.path")
track_type = runtime.eval('require("TrackMath")')[0]
vehicle_type = runtime.eval('require("VehicleSimulation")')[0]


def table(value):
    if isinstance(value, dict):
        return runtime.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return runtime.table_from([table(v) for v in value])
    return value


city = json.loads((ROOT / "docs/reference/qqfeiche3d/tracks/city.json").read_text())
# Wide flat closed oval isolates long drifting and speed from incidental rail hits.
import math
n = 1000
px = [math.sin(i * 2 * math.pi / n) * 10000 for i in range(n)]
pz = [math.cos(i * 2 * math.pi / n) * 10000 for i in range(n)]
ds = sum(math.hypot(px[(i + 1) % n] - px[i], pz[(i + 1) % n] - pz[i]) for i in range(n)) / n
arrays = dict(px=px, pz=pz, py=[0]*n, hd=[math.atan2(px[(i+1)%n]-px[(i-1)%n], pz[(i+1)%n]-pz[(i-1)%n]) for i in range(n)],
              bank=[0]*n, slope=[0]*n, vcurv=[0]*n, sslope=[0]*n)
flat = dict(track=dict(samples=n, length=ds*n, sampleDistance=ds, halfWidth=1000, arrays=arrays), boostPads=[])
cases = []


def add(name, seconds, inputs, initial=None, track=flat, distance=0, actions=None):
    cases.append(dict(name=name, track=track, initial=initial or {}, distance=distance,
                      frames=[dict(input=inputs(i), action=(actions or {}).get(i)) for i in range(round(seconds*120))]))


add("accel-coast-brake-reverse", 15, lambda i: {"up":i<720, "down":i>=960})
add("left-drift-two-slots", 14, lambda i: {"up":True,"shift":i>=240,"left":i>=240})
add("right-drift-release", 6, lambda i: {"up":True,"shift":240<=i<360,"right":240<=i<360,"left":360<=i<420})
add("perfect-small-double", 2, lambda i: {"up":True,"upPressed":i==0,"nitroPressed":i in (0,12,24)},
    dict(s=35,smallWindow=0.5,windowKind="drift",nitroCount=2))
add("late-small", 1, lambda i: {"up":True,"upPressed":i==30}, dict(s=35,smallWindow=0.5,windowKind="drift"))
add("expired-small", 1, lambda i: {"up":True,"upPressed":i==65}, dict(s=35,smallWindow=0.5,windowKind="drift"))
add("nitro-then-small", 2, lambda i: {"up":True,"upPressed":i==12,"nitroPressed":i==0},
    dict(s=35,smallWindow=0.5,windowKind="drift",nitroCount=2))
add("start-boost", 3, lambda i: {"up":True}, actions={0:"start"})
add("air-land-boost", 2, lambda i: {"up":True,"upPressed":i==85}, dict(s=35,y=3,vy=3,airborne=True))
add("city-pad-wall", 12, lambda i: {"up":True,"right":i>500}, track=city, distance=170)
reference = subprocess.run(["node",str(ROOT / "tools/racing_reference.cjs")], input=json.dumps(cases),
                           text=True, capture_output=True, cwd=ROOT, check=True)
expected = json.loads(reference.stdout)
results, global_error = [], 0
for case, reference_frames in zip(cases, expected):
    data = {**case["track"]["track"], "boostPads":case["track"]["boostPads"]}
    t = track_type.new(table(data))
    car = vehicle_type.new(t, case["distance"], 0)
    for key, value in case["initial"].items():
        car[key] = value
    maximum, events, samples = 0, [], []
    for index, (frame, original) in enumerate(zip(case["frames"],reference_frames)):
        if frame["action"] == "start": car.applyStartBoost(car)
        car.update(car, 1/120, table(frame["input"]), True, False)
        for key, value in original.items():
            if key in ("events","isPlayer","hint"): continue
            actual = car[key]
            if isinstance(value,bool) or isinstance(value,str):
                assert actual == value, (case["name"],index,key,value,actual)
            else:
                error = abs(value - actual)
                maximum = max(maximum,error)
                assert error < 1e-7, (case["name"],index,key,value,actual,error)
        assert car.hint == original["hint"]+1, (case["name"], index, car.hint, original["hint"])
        actual_events = [car.events[i] for i in range(1,len(car.events)+1)]
        # Start is emitted by the wrapper in Lua; original HUD handled it outside Yo.
        actual_events = [e for e in actual_events if e.type != "startBoost"]
        assert [e.type for e in actual_events] == [e["type"] for e in original["events"]], (case["name"],index)
        for a, e in zip(actual_events, original["events"]):
            for k,v in e["data"].items():
                assert a.data[k] == v or (isinstance(v,(float,int)) and abs(a.data[k]-v)<1e-7)
        events.extend(e["type"] for e in original["events"])
        car.events = runtime.table()
        if index % 120 == 0:
            samples.append(dict(t=(index+1)/120,speed=car.s,x=car.x,y=car.y,z=car.z))
    global_error = max(global_error,maximum)
    results.append(dict(name=case["name"],steps=len(case["frames"]),maxError=maximum,
                        events={e:events.count(e) for e in sorted(set(events))},
                        nitroCount=car.nitroCount,gauge=car.gauge,samples=samples))
assert results[1]["nitroCount"] == 2
assert results[3]["events"].get("double",0) > 0
assert results[8]["events"].get("landBoost",0) == 1
out = ROOT / "docs/verification/step-4"
out.mkdir(parents=True,exist_ok=True)
report = dict(passed=True,totalSteps=sum(r["steps"] for r in results),maxError=global_error,cases=results)
(out/"simulation-comparison.json").write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!="cases"},indent=2))
