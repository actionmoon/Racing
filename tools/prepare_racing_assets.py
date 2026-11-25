"""Prepare the captured Three.js scene for the Unity racingmesh importer."""
import argparse
import base64
import hashlib
import json
import re
import shutil
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("capture", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
target = root / "unity/Assets/RacingClone"
data = json.loads(args.capture.read_text())
point_geometries = {node["geometry"] for node in data["city"] if node["type"] == "Points"}
for node in data["city"]:
    if node["type"] == "Points":
        node["geometry"] = ""
data["geometries"] = [geo for geo in data["geometries"] if geo["id"] not in point_geometries]
textures = target / "Textures"
source = target / "Source"
textures.mkdir(parents=True, exist_ok=True)
source.mkdir(parents=True, exist_ok=True)
by_hash = {}
for png in sorted((root / "docs/reference/qqfeiche3d/textures").glob("*.png")):
    shutil.copy2(png, textures / png.name)
    by_hash[hashlib.sha256(png.read_bytes()).hexdigest()] = png.name
for texture in data["textures"]:
    payload = base64.b64decode(texture.pop("png").split(",", 1)[1])
    digest = hashlib.sha256(payload).hexdigest()
    if digest not in by_hash:
        name = f"captured-{digest[:12]}.png"
        (textures / name).write_bytes(payload)
        by_hash[digest] = name
    texture["asset"] = f"Assets/RacingClone/Textures/{by_hash[digest]}"
    texture["sha256"] = digest
script = (root / "docs/reference/qqfeiche3d/readable-script.js").read_text()
skins = script.split("var Ui = [", 1)[1].split("];", 1)[0]
data["skins"] = [
    {
        "id": re.search(r'id: "([^"]+)"', block)[1],
        **{key: int(re.search(rf"{key}: (\d+)", block)[1])
           for key in ("body", "accent", "glow", "rim")},
    }
    for block in re.findall(r"\{([^{}]+)\}", skins)
]
map_id = data["map"]
if map_id not in ("city", "aegean", "egypt", "snow"):
    raise ValueError(f"Unknown map: {map_id}")
track = json.loads((root / f"docs/reference/qqfeiche3d/tracks/{map_id}.json").read_text())
data["track"] = track["track"]
data["config"] = track["config"]
output = source / f"{map_id.capitalize()}.racingmesh"
output.write_text(json.dumps(data, separators=(",", ":"), ensure_ascii=False))
print(f"{output}: {len(data['geometries'])} meshes, {len(by_hash)} textures, {len(data['skins'])} skins")
