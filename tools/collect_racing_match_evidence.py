"""Collect sanitized match evidence from one completed DS verification session."""
import argparse
import copy
import hashlib
import json
import re
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument("session",type=Path)
parser.add_argument("--output",type=Path,default=Path("/tmp/racing-step5-runtime.json"))
args=parser.parse_args()
packets,phases,errors={}, {}, {}
for role in ("server","client-1","client-2"):
    lines=(args.session/(role+".log")).read_text(errors="replace").splitlines()
    packets[role]={}
    phases[role]=[]
    for line in lines:
        if "] MATCH " in line:
            packet=json.loads(line.split("] MATCH ",1)[1])
            packets[role][packet["tick"]]=packet
        if "] PHASE " in line:
            match=re.search(r"epoch=(\d+) phase=(\w+) time=([0-9.eE+-]+)",line)
            if match: phases[role].append({"epoch":int(match[1]),"phase":match[2],"time":float(match[3])})
    errors[role]={
        "luaExceptions":sum("LuaException" in l for l in lines),
        "sdkNullReferences":sum("NullReferenceException:" in l for l in lines),
        "networkActorTransformStack":sum("NetworkActorTransformDataComponent" in l for l in lines),
    }
common=set(packets["server"]) & set(packets["client-1"]) & set(packets["client-2"])
assert common, "No common match ticks"
for tick in common:
    assert packets["server"][tick]==packets["client-1"][tick]==packets["client-2"][tick],tick
assert all(e["luaExceptions"]==0 for e in errors.values()),errors
for role,sequence in phases.items():
    assert [s["phase"] for s in sequence]==["menu","countdown","race","pause","race","result","countdown","pause","menu"],(role,sequence)
result=next(p for p in packets["server"].values() if p["match"]["phase"]=="result")
assert len(result["cars"])==6
assert sum(not c["isAI"] for c in result["cars"])==2
assert all(c["finished"] for c in result["cars"] if not c["isAI"])
assert all(next(s["time"] for s in sequence if s["phase"]=="result")==result["match"]["time"] for sequence in phases.values())
paused=next(s for s in phases["server"] if s["phase"]=="pause" and s["time"]>0)
paused_packets=[p for p in packets["server"].values() if p["epoch"]==paused["epoch"]]
assert len(paused_packets)>=2, "Need at least two paused snapshots"
assert all(p["match"]["time"]==paused["time"] for p in paused_packets)
assert all([c["state"] for c in p["cars"]]==[c["state"] for c in paused_packets[0]["cars"]] for p in paused_packets)
human_ids=[c["id"] for c in result["cars"] if not c["isAI"]]
id_map={value:"player-"+str(i+1) for i,value in enumerate(human_ids)}

def sanitize(packet):
    p=copy.deepcopy(packet)
    p["match"]["host"]=id_map.get(p["match"]["host"],p["match"]["host"])
    p["match"]["controlAcks"]={id_map.get(k,k):v for k,v in p["match"]["controlAcks"].items()}
    for car in p["cars"]:
        car["id"]=id_map.get(car["id"],car["id"])
    return p

report={"passed":True,"session":str(args.session),"commonTicks":len(common),"tickRange":[min(common),max(common)],
        "sharedResultTime":result["match"]["time"],"pausedTime":paused["time"],"phaseSequences":phases,
        "errors":errors,"result":sanitize(result),
        "snapshotDigests":[{"tick":tick,"sha256":hashlib.sha256(json.dumps(packets["server"][tick],sort_keys=True).encode()).hexdigest()} for tick in sorted(common)]}
args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in report.items() if k not in ("result","snapshotDigests")},ensure_ascii=False,indent=2))
