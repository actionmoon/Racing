"""Collect presentation checks without exporting raw SDK account logs."""
import argparse
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("sessions", nargs="+", type=Path)
parser.add_argument("--output", type=Path, default=Path("step-7-verification/manual-runtime.json"))
args = parser.parse_args()
setting_pattern = re.compile(
    r"SETTING action=(\w+) quality=(\d+) camera=(\d+) music=(true|false) song=(\d+) post=(true|false)"
)
output_pattern = re.compile(r"OUTPUT rms=([\d.]+) peak=([\d.]+)")
reports = []
for folder in args.sessions:
    manifest = json.loads((folder / "session.json").read_text())
    roles = {}
    for role in ("server", "client-1", "client-2"):
        settings, inputs, events, renders = [], [], {}, []
        outputs = {"samples": 0, "nonzero": 0, "zero": 0, "maxRms": 0, "maxPeak": 0}
        touch_states, songs, layouts = {}, set(), set()
        errors, sdk_wrapped_errors, sdk_errors = set(), set(), 0
        last_error, last_error_line = None, -100
        hidden, simultaneous_drift = False, False
        with (folder / f"{role}.log").open(errors="replace") as stream:
            for line_number, line in enumerate(stream, 1):
                sdk_errors += "NullReferenceException" in line
                if "name:LuaException" in line:
                    last_error = line.split("reason:", 1)[-1].strip()[:400]
                    last_error_line = line_number
                    errors.add(last_error)
                if last_error and line_number-last_error_line < 25 and "Hamlet.GameLaunch.Log.LogToEditorConsole" in line:
                    errors.discard(last_error)
                    sdk_wrapped_errors.add(last_error)
                if "[RacingClone]" not in line:
                    continue
                marker = line[line.index("[RacingClone]"):].strip()
                setting = setting_pattern.search(marker)
                if setting:
                    action, quality, camera, music, song, post = setting.groups()
                    settings.append({
                        "line": line_number, "action": action, "quality": int(quality),
                        "camera": int(camera), "music": music == "true",
                        "song": int(song), "post": post == "true",
                    })
                output = output_pattern.search(marker)
                if output:
                    rms, peak = map(float, output.groups())
                    outputs["samples"] += 1
                    outputs["nonzero"] += rms > 0.00001
                    outputs["zero"] += rms == 0
                    outputs["maxRms"] = max(outputs["maxRms"], rms)
                    outputs["maxPeak"] = max(outputs["maxPeak"], peak)
                touch = re.search(r"TOUCH action=(\w+) held=(true|false)", marker)
                if touch:
                    action, held = touch.groups()
                    touch_states.setdefault(action, set()).add(held)
                    inputs.append({"line": line_number, "text": marker})
                if "MANUAL_INPUT" in marker:
                    inputs.append({"line": line_number, "text": marker})
                    simultaneous_drift |= "up=true left=true right=false shift=true" in marker
                event = re.search(r"(?:AUDIO_EVENT name|EVENT type)=(\w+)", marker)
                if event:
                    name = event.group(1)
                    events[name] = events.get(name, 0) + 1
                song = re.search(r"AUDIO song=(\d+) playing=true", marker)
                if song:
                    songs.add(int(song.group(1)))
                if "LAYOUT " in marker:
                    layouts.add(marker)
                if "RENDER " in marker:
                    if not renders or renders[-1]["text"] != marker:
                        renders.append({"line": line_number, "text": marker})
                hidden |= "SYSTEM_UI_HIDDEN" in marker
        roles[role] = {
            "settings": settings, "inputMarkers": inputs,
            "touchStates": {key: sorted(value) for key, value in touch_states.items()},
            "simultaneousKeyboardAndTouchDrift": simultaneous_drift,
            "events": events, "playingSongs": sorted(songs), "output": outputs,
            "layouts": sorted(layouts), "renderStates": renders,
            "systemUIHidden": hidden, "luaErrors": sorted(errors),
            "sdkLoggerErrorsWrappedAsLua": sorted(sdk_wrapped_errors),
            "sdkNullReferences": sdk_errors,
        }
    reports.append({"session": str(folder), "roles": roles, "_manifest": manifest})

restarts = []
keys = ("quality", "camera", "music", "song")
for previous, following in zip(reports, reports[1:]):
    for role in ("client-1", "client-2"):
        before, after = previous["roles"][role]["settings"], following["roles"][role]["settings"]
        if not before or not after:
            continue
        first = {key: before[-1][key] for key in keys}
        second = {key: after[0][key] for key in keys}
        a = next((entry for entry in previous["_manifest"] if entry["role"] == role), {})
        b = next((entry for entry in following["_manifest"] if entry["role"] == role), {})
        restarts.append({
            "from": previous["session"], "to": following["session"], "role": role,
            "sameIdentity": bool(a.get("identityTag")) and a.get("identityTag") == b.get("identityTag"),
            "before": first, "after": second, "settingsRestored": first == second,
        })
for report in reports:
    report.pop("_manifest")
args.output.write_text(json.dumps({"sessions": reports, "restarts": restarts}, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({
    "output": str(args.output),
    "sessions": [{"session": r["session"], "clientLuaErrors": {
        role: len(r["roles"][role]["luaErrors"]) for role in ("client-1", "client-2")
    }} for r in reports],
    "restarts": restarts,
}, ensure_ascii=False, indent=2))
