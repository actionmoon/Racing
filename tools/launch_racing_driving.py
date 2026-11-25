"""Launch the authorized DS driving check; secrets stay in a temporary file."""
import json
import os
import subprocess
from pathlib import Path

step = os.environ.get("RACING_VERIFY_STEP", "4")
auth_file = Path(os.environ.get("RACING_AUTH_FILE", "/tmp/racing-step4-auth.json"))
auth = json.loads(auth_file.read_text())
auth_file.unlink()
players = json.loads(os.environ.get("RACING_VERIFY_PLAYERS", '["赛车验证1","赛车验证2"]'))
env = os.environ.copy()
env["HAMLET_ACCESS_TOKEN"] = auth["token"]
env["HAMLET_DEVICE_ID"] = auth["device"]
args = [
    "python3", ".trae/skills/hamlet-debugging/scripts/simulator.py",
    "--project", "unity", "--mode", "ds", "--players",
    *players,
    "--scene", os.environ.get("RACING_VERIFY_SCENE","Assets/Scenes/RacingClone.unity"), "--room", "0",
    "--network", "new", "--data-store", "off", "--pawn-actor-type", "avatar",
    "--windowless", "--server-ready-pattern", "SERVER_READY",
]
for role in ["server", *[f"client-{i+1}" for i in range(len(players))]]:
    args += ["--instance-executable", f"{role}=/tmp/racing-debugger/{role}/DouyinWorldDebugger.app"]
with open(f"/tmp/racing-step{step}-dryrun.log", "w") as log:
    subprocess.run(args + ["--dry-run"], env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
with open(f"/tmp/racing-step{step}-launch.log", "w") as log:
    subprocess.run(args + ["--hold"], env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
