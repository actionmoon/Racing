"""Extract shareable racing markers and compare authoritative snapshots."""
import argparse
import collections
import datetime
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("sessions", nargs="+")
parser.add_argument("--output", default="docs/verification/step-4/runtime-evidence.json")
args = parser.parse_args()
root = Path("/var/folders/t5/cx_l90z95vx72xgc8ps0j8n80000gn/T")
snapshot = re.compile(r"(?:STATE|SNAPSHOT) tick=(\d+) id=(\d+) ack=(\d+) x=([\d.-]+) z=([\d.-]+) speed=([\d.-]+)")
results = []
for name in args.sessions:
    folder = root / name
    manifest = json.loads((folder / "session.json").read_text())
    roles, states = {}, {}
    for instance in manifest:
        role = instance["role"]
        path = Path(instance["logFile"])
        lines = path.read_text(errors="replace").splitlines()
        markers, categories, values = [], collections.defaultdict(list), {}
        for number, line in enumerate(lines, 1):
            if "[RacingClone]" not in line:
                continue
            clean = line[line.index("[RacingClone]"):]
            marker = {"line": number, "text": clean}
            key = "Fixture" if "[Fixture]" in clean else "EVENT" if " EVENT " in clean else "SNAPSHOT" if " SNAPSHOT " in clean else "PREDICT" if " PREDICT " in clean else "STATE" if " STATE " in clean else "lifecycle"
            categories[key].append(marker)
            match = snapshot.search(clean)
            if match:
                tick, driver, ack, x, z, speed = match.groups()
                if role == "server" or "SNAPSHOT" in clean:
                    values[(int(tick), driver, int(ack))] = tuple(map(float, (x, z, speed)))
        for key, entries in categories.items():
            selected = entries[:160] if key == "EVENT" else entries if len(entries) <= 12 else entries[:6] + entries[-6:]
            markers.extend(selected)
        errors = {key: sum(key in line for line in lines) for key in ("LuaException", "NullReferenceException", "guid已重复收集", "AvatarData")}
        stack = []
        for i, line in enumerate(lines):
            if line.startswith("NullReferenceException:"):
                stack = [line]
                for following in lines[i+1:i+12]:
                    if not following.startswith("  at "):
                        break
                    stack.append(following)
                break
        roles[role] = {"pid": instance["pid"], "roomTag": instance["roomTag"], "logFile": str(path),
                       "markerCounts": {k: len(v) for k, v in categories.items()},
                       "markers": sorted(markers, key=lambda x: x["line"]), "errorCounts": errors,
                       "firstNullReferenceStack": stack}
        states[role] = values
    common = set(states.get("server", {}))
    for role in ("client-1", "client-2"):
        common &= set(states.get(role, {}))
    comparisons = []
    for key in sorted(common):
        authoritative = states["server"][key]
        error = max(abs(a-b) for role in ("client-1", "client-2")
                    for a, b in zip(authoritative, states[role][key]))
        comparisons.append({"tick": key[0], "driver": key[1], "ack": key[2],
                            "x": authoritative[0], "z": authoritative[1], "speed": authoritative[2],
                            "maxErrorAtSixDecimalLogPrecision": error})
    results.append({"session": str(folder), "roles": roles, "threeWaySnapshotCount": len(comparisons),
                    "threeWaySnapshots": comparisons})
target = Path(args.output)
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(json.dumps({"generatedAt": datetime.datetime.now().isoformat(),
                             "precisionNote": "Comparisons use six-decimal authoritative log values; client prediction may be ahead.",
                             "sessions": results}, ensure_ascii=False, indent=2) + "\n")
print(target)
for result in results:
    print(Path(result["session"]).name, "threeWaySnapshots=", result["threeWaySnapshotCount"],
          "maxError=", max((x["maxErrorAtSixDecimalLogPrecision"] for x in result["threeWaySnapshots"]), default=None))
