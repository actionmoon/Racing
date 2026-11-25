"""Collect sanitized production-scene UI or single-player runtime evidence."""
import argparse
import copy
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("session", type=Path)
parser.add_argument("--output", required=True, type=Path)
parser.add_argument("--solo", action="store_true")
args = parser.parse_args()
roles = ["server", "client-1"] if args.solo else ["server", "client-1", "client-2"]
packets, phases, errors, controls = {}, {}, {}, []
for role in roles:
    lines = (args.session / (role + ".log")).read_text(errors="replace").splitlines()
    packets[role], phases[role] = {}, []
    for line in lines:
        if "] MATCH " in line:
            packet = json.loads(line.split("] MATCH ", 1)[1])
            packets[role][packet["tick"]] = packet
        if "] PHASE " in line:
            match = re.search(r"epoch=(\d+) phase=(\w+) time=([0-9.eE+-]+)", line)
            if match:
                phases[role].append(dict(epoch=int(match[1]), phase=match[2], time=float(match[3])))
        if role == "server" and "] CONTROL " in line:
            match = re.search(r"action=(\w+) accepted=(\w+) epoch=(\d+)", line)
            if match:
                controls.append(dict(action=match[1], accepted=match[2] == "true", epoch=int(match[3])))
    errors[role] = {
        "luaExceptions": sum("LuaException" in line for line in lines),
        "sdkNullReferences": sum("NullReferenceException:" in line for line in lines),
        "networkActorTransformStack": sum("NetworkActorTransformDataComponent" in line for line in lines),
    }
assert all(x["luaExceptions"] == 0 for x in errors.values()), errors
common = set.intersection(*(set(packets[r]) for r in roles))
assert common
assert all(all(packets[r][t] == packets["server"][t] for r in roles) for t in common)
server = list(packets["server"].values())
paused = [p for p in server if p["match"]["phase"] == "pause"]
freeze_checks = []
for epoch in sorted({p["epoch"] for p in paused}):
    group = [p for p in paused if p["epoch"] == epoch]
    assert len(group) >= 2
    assert all(p["match"]["time"] == group[0]["match"]["time"] for p in group)
    assert all([c["state"] for c in p["cars"]] == [c["state"] for c in group[0]["cars"]] for p in group)
    freeze_checks.append(dict(epoch=epoch, time=group[0]["match"]["time"], snapshots=len(group)))
required = {"start"} if args.solo else {"laps", "diff", "skin", "start", "pause", "resume", "restart", "quit"}
assert required <= {c["action"] for c in controls if c["accepted"]}
result = next(p for p in server if p["match"]["phase"] == "result")
assert len(result["cars"]) == 6
assert sum(c["isAI"] for c in result["cars"]) == (5 if args.solo else 4)
assert all(c["finished"] for c in result["cars"] if c["isAI"])
ids = {c["id"]: "player-" + str(i + 1) for i, c in enumerate(c for c in result["cars"] if not c["isAI"])}
def sanitize(packet):
    p = copy.deepcopy(packet)
    p["match"]["host"] = ids.get(p["match"]["host"], p["match"]["host"])
    p["match"]["controlAcks"] = {ids.get(k, k): v for k, v in p["match"]["controlAcks"].items()}
    for c in p["cars"]:
        if not c["isAI"]:
            c["id"], c["name"] = ids.get(c["id"], "departed-player"), ids.get(c["id"], "departed-player")
    return p
report = dict(
    passed=True, scene="Assets/Scenes/RacingClone.unity", input="OS mouse/keyboard; no fixture",
    session=str(args.session), roles=roles, commonSnapshots=len(common), phaseSequences=phases,
    controls=controls, pausedFreeze=freeze_checks, errors=errors, result=sanitize(result),
    resultTime=result["match"]["time"], humanFinished=sum(c["finished"] for c in result["cars"] if not c["isAI"]),
)
args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2))
print(json.dumps({k: v for k, v in report.items() if k not in ("result", "phaseSequences")}, ensure_ascii=False, indent=2))
