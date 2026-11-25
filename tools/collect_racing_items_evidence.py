"""Collect exact common snapshots and item events from DS verification logs."""
import argparse
import copy
import hashlib
import json
import re
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument("session",type=Path)
parser.add_argument("--output",type=Path,required=True)
parser.add_argument("--fixture",action="store_true")
args=parser.parse_args()
packets,events,errors,controls={},{},{},{}
malformed={}
for role in ("server","client-1","client-2"):
    lines=(args.session/(role+".log")).read_text(errors="replace").splitlines()
    packets[role],events[role],controls[role],malformed[role]={},{},[],0
    for line in lines:
        marker="][Fixture] FRAME " if args.fixture else "] MATCH "
        if marker in line:
            try:
                packet=json.loads(line.split(marker,1)[1])
            except json.JSONDecodeError:
                malformed[role]+=1
                continue
            packets[role][packet["tick"]]=packet
        if "] ITEM " in line:
            try:
                event=json.loads(line.split("] ITEM ",1)[1])
            except json.JSONDecodeError:
                malformed[role]+=1
                continue
            events[role][event["id"]]=event
        if "] CONTROL " in line:
            controls[role].append(line.split("] CONTROL ",1)[1])
    sdk_logger_records=sum("LuaException" in line and "System.ArgumentOutOfRangeException" in line
        and "chunkLength" in "\n".join(lines[i:i+8])
        and "Hamlet.GameLaunch.Log.LogToEditorConsole" in "\n".join(lines[i:i+8])
        for i,line in enumerate(lines))
    lua_records=sum("LuaException" in l for l in lines)
    errors[role]={
        "luaExceptions":lua_records,
        "sdkLoggerLuaRecords":sdk_logger_records,
        "unexpectedLuaExceptions":lua_records-sdk_logger_records,
        "sdkNullReferences":sum("NullReferenceException:" in l for l in lines),
        "networkActorTransformStack":sum("NetworkActorTransformDataComponent" in l for l in lines)}
common=set(packets["server"])&set(packets["client-1"])&set(packets["client-2"])
assert common,"No common snapshot ticks"
for tick in common:
    assert packets["server"][tick]==packets["client-1"][tick]==packets["client-2"][tick],tick
assert all(e["unexpectedLuaExceptions"]==0 for e in errors.values()),errors
shared=[]
for tick in sorted(common):
    packet=packets["server"][tick]
    for event in packet["items"]["events"]:
        key=(packet["epoch"],event["id"])
        if key not in {(p["epoch"],p["event"]["id"]) for p in shared}:
            shared.append({"epoch":packet["epoch"],"event":event})
latest=packets["server"][max(common)]
ids={car["id"]:"player-"+str(i+1) for i,car in enumerate(latest["cars"]) if not car["isAI"]}
def sanitize(value):
    p=copy.deepcopy(value)
    p["match"]["host"]=ids.get(p["match"]["host"],p["match"]["host"])
    p["match"]["controlAcks"]={ids.get(k,k):v for k,v in p["match"]["controlAcks"].items()}
    for car in p["cars"]: car["id"]=ids.get(car["id"],car["id"])
    return p
report={"passed":True,"session":str(args.session),"commonTicks":len(common),
    "tickRange":[min(common),max(common)],"errors":errors,"malformedLogRecords":malformed,"controls":controls,"sharedEvents":shared,
    "snapshotDigests":[{"tick":tick,"sha256":hashlib.sha256(json.dumps(packets["server"][tick],sort_keys=True).encode()).hexdigest()} for tick in sorted(common)],
    "latest":sanitize(latest)}
if args.fixture:
    cases={}
    for tick in common:
        p=packets["server"][tick]
        name=p["match"].get("verification","")
        cases.setdefault(name,[]).append(p)
    report["cases"]={name:len(values) for name,values in cases.items()}
    def event_in(name,kind,item=None,slot=None):
        return any(e["type"]==kind and (item is None or e["item"]==item)
            and (slot is None or e["slot"]==slot)
            for p in cases.get(name,[]) for e in p["items"]["events"])
    checks={
        "manualTwoSwaps":any(sum(e["type"]=="swap" and e["slot"]==1
            for e in p["items"]["events"])>=2 for p in cases.get("manual_slots",[])),
        "manualNitro":event_in("manual_slots","use","nitro",1),
        "manualShield":event_in("manual_slots","use","shield",1),
        "shieldBlocksMissile":event_in("shield_missile","block","missile",1)
            and not event_in("shield_missile","hit","missile",1),
        "missileHits":event_in("missile_hit","hit","missile",1),
        "magnetWithoutTarget":any(p["cars"][0]["state"]["magnet"]>0
            and p["cars"][0]["magnetTarget"]==0 for p in cases.get("magnet_none",[])),
        "magnetWithTarget":any(p["cars"][1]["state"]["magnet"]>0
            and p["cars"][1]["magnetTarget"]==1 for p in cases.get("magnet_target",[])),
        "bananaHitsOpponent":event_in("banana_other","hit","banana",2),
        "bananaOwnerImmune":any(p["items"]["bananas"] and
            0.5<p["items"]["bananas"][0]["age"]<1.2 and
            not any(e["type"]=="hit" for e in p["items"]["events"])
            for p in cases.get("banana_self",[])),
        "bananaHitsOwnerAfterImmunity":event_in("banana_self","hit","banana",1)
    }
    flow={}
    for role in packets:
        text=(args.session/(role+".log")).read_text(errors="replace")
        if role!="server":
            flow[role]={name:name in text for name in ("PAUSE_OBSERVED","NATURAL_RESULT","FLOW_COMPLETE")}
    checks["naturalFlow"]=any(all(values.values()) for values in flow.values())
    checks["realTouchSwap"]=any("TOUCH action=swap held=true" in
        (args.session/(role+".log")).read_text(errors="replace") for role in ("client-1","client-2"))
    checks["realTouchUse"]=any("TOUCH action=nitro held=true" in
        (args.session/(role+".log")).read_text(errors="replace") for role in ("client-1","client-2"))
    paused=[p for p in cases.get("natural",[]) if p["match"]["phase"]=="pause"
        and p["match"]["time"]>0]
    checks["pauseFreezesClock"]=len(paused)>=2 and len({p["match"]["time"] for p in paused})==1
    menus=[p for p in cases.get("natural",[]) if p["match"]["phase"]=="menu"]
    checks["returnClearsItems"]=bool(menus) and all(not c["items"] for c in menus[-1]["cars"]) \
        and not menus[-1]["items"]["bananas"] and not menus[-1]["items"]["missiles"] \
        and all(t==0 for t in menus[-1]["items"]["boxes"])
    report["checks"],report["flow"]=checks,flow
    assert all(checks.values()),checks
    results=[p for p in packets["server"].values() if p["match"]["phase"]=="result"]
    assert results,"Natural item race did not finish"
    report["naturalResult"]=sanitize(results[-1])
    report["naturalResultTime"]=results[-1]["match"]["time"]
args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in report.items() if k not in ("latest","naturalResult","snapshotDigests","sharedEvents")},ensure_ascii=False,indent=2))
