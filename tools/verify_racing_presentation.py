"""Summarize real DS runs without exporting account or device information."""
import argparse
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("session", type=Path)
parser.add_argument("--output", type=Path, default=Path("/tmp/racing-step7-runtime.json"))
args = parser.parse_args()
roles = {}
for role in ("server", "client-1", "client-2"):
    text = (args.session / f"{role}.log").read_text(errors="replace")
    snapshots = {}
    for line in text.splitlines():
        marker = "[PresentationFixture] RESULT " if role != "server" else "[Server] MATCH "
        if marker not in line:
            continue
        packet = json.loads(line.split(marker, 1)[1])
        if packet.get("match", {}).get("phase") == "result":
            snapshots[packet["match"]["settings"]["map"]] = packet
    races = {}
    for map_id, packet in snapshots.items():
        cars = packet.get("cars", [])
        races[map_id] = {
            "epoch": packet["epoch"],
            "time": packet["match"]["time"],
            "finishers": sum(car["finished"] for car in cars),
            "players": sum(not car["isAI"] for car in cars),
            "state": [
                {key: car[key] for key in ("slot", "rank", "finished", "finishTime", "lapsDone")}
                for car in cars
            ],
        }
    outputs = re.findall(r"\[PresentationFixture\] OUTPUT rms=([\d.]+) peak=([\d.]+)", text)
    roles[role] = {
        "races": races,
        "visibleMaps": sorted(set(re.findall(r"MAP_VISIBLE id=(\w+)", text))),
        "quality": sorted(set(int(value) for value in re.findall(r"QUALITY requested=(\d+) actual=\1", text))),
        "output": {
            "samples": len(outputs),
            "nonzero": sum(float(rms) > 0.00001 for rms, _ in outputs),
            "maxRms": max((float(rms) for rms, _ in outputs), default=0),
            "maxPeak": max((float(peak) for _, peak in outputs), default=0),
        },
        "layouts": sorted(set(re.findall(r"LAYOUT width=(\d+) height=(\d+) portrait=(\w+)", text))),
        "luaExceptions": text.count("LuaException"),
        "outputErrors": text.count("[PresentationFixture] OUTPUT_ERROR"),
        "sdkNullReferences": text.count("NullReferenceException"),
        "flowComplete": "[PresentationFixture] FLOW_COMPLETE maps=4" in text,
        "mapPermissionRejected": "CONTROL action=map accepted=false" in text,
    }
maps = ["city", "aegean", "egypt", "snow"]
checks = {}
for role, result in roles.items():
    for map_id in maps:
        race = result["races"].get(map_id, {})
        checks[f"{role} {map_id} six finishers"] = race.get("finishers") == 6 and race.get("players") == 2
    checks[f"{role} no Lua exceptions"] = result["luaExceptions"] == 0
    if role != "server":
        checks[f"{role} four visible maps"] = result["visibleMaps"] == sorted(maps)
        checks[f"{role} three qualities"] = result["quality"] == [0, 1, 2]
        checks[f"{role} actual audio output"] = result["output"]["nonzero"] > 3 and result["outputErrors"] == 0
for map_id in maps:
    states = [result["races"].get(map_id, {}).get("state") for result in roles.values()]
    checks[f"{map_id} result agrees across DS and clients"] = bool(states[0]) and states[0] == states[1] == states[2]
checks["nonhost map rejected"] = roles["server"]["mapPermissionRejected"]
checks["four map flow completed"] = roles["client-1"]["flowComplete"]
report = {"passed": all(checks.values()), "checks": checks, "roles": roles}
args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2))
print(json.dumps({"passed": report["passed"], "checks": checks}, ensure_ascii=False, indent=2))
raise SystemExit(0 if report["passed"] else 1)
