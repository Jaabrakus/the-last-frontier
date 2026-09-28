#!/usr/bin/env python3
"""Export real animation assets in an isolated fixture and compare release/debug packs.

python3 tests/export/test_export_pack.py --godot /path/to/Godot
No source project or editor settings are rewritten. Output/logs stay in the printed temp folder.
On macOS the standard (non-Mono) executable is copied into self-contained mode for the fixture.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
FILES = [
    "animations/Actor_B.res", "animations/actor_b_graph.json", "animations/actor_b_clip_metrics.json",
    "animations_extra/Actor_B_from_A.res", "animations_extra/Actor_B_from_C.res",
    "animations_extra/actor_a_rt_proto.res", "animations_extra/Frontier_Own.res",
    "characters/Actor_B.tscn", "data/climb/climb_tree.json",
]


def checksum(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    args = parser.parse_args()
    output = Path(tempfile.mkdtemp(prefix="frontier-export-check-"))
    fixture = output / "project"
    fixture.mkdir()
    print(f"Export fixture and logs: {output}", flush=True)
    before = {name: checksum(ROOT / name) for name in FILES}
    for name in FILES:
        target = fixture / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / name, target)
    shutil.copytree(ROOT / "addons/release_metadata", fixture / "addons/release_metadata")
    shutil.copy2(ROOT / "tests/export/pack_probe.gd", fixture / "pack_probe.gd")
    (fixture / "CREDITS.md").write_text("Fixture credits remain present.\n")
    (fixture / "unrelated.json").write_text(json.dumps({"source_attribution": "fixture record"}))
    (fixture / "main.tscn").write_text(
        '[gd_scene load_steps=2 format=3]\n'
        '[ext_resource type="Script" path="res://pack_probe.gd" id="1"]\n'
        '[node name="PackProbe" type="Node"]\nscript = ExtResource("1")\n'
    )
    (fixture / "project.godot").write_text(
        'config_version=5\n[application]\nconfig/name="Release metadata fixture"\n'
        'run/main_scene="res://main.tscn"\n[editor_plugins]\n'
        'enabled=PackedStringArray("res://addons/release_metadata/plugin.cfg")\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
    )
    (fixture / "export_presets.cfg").write_text(
        '[preset.0]\nname="Fixture"\nplatform="Linux"\nrunnable=true\n'
        'export_filter="all_resources"\ninclude_filter="*.json,CREDITS.md"\n'
        'exclude_filter="addons/*"\nscript_export_mode=2\n'
        '[preset.0.options]\nbinary_format/architecture="x86_64"\n'
    )
    # Self-contained mode keeps Godot's editor data out of the user's real editor settings.
    binary_dir = output / "engine"
    binary_dir.mkdir()
    engine = binary_dir / "Godot"
    shutil.copyfile(args.godot.resolve(), engine)
    engine.chmod(0o755)
    if sys.platform == "darwin":
        # A signed app executable loses its bundle context when copied; sign only this
        # temporary standalone copy so macOS permits it to launch in self-contained mode.
        subprocess.run(["codesign", "--force", "--sign", "-", str(engine)], check=True,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (binary_dir / "_sc_").touch()

    def run(label, *command_args):
        result = subprocess.run(
            [str(engine), "--headless", "--path", str(fixture), "--log-file", str(output / (label + ".engine.log")), *command_args],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180,
        )
        (output / (label + ".log")).write_text(result.stdout)
        # A macOS system-certificate lookup can fail in a filesystem sandbox, independently
        # of export/playback. Every script/export error still fails this test, even with exit 0.
        errors = [line for line in result.stdout.splitlines() if re.match(r"(?:SCRIPT )?ERROR:", line)]
        errors = [line for line in errors if 'Condition "ret != noErr"' not in line]
        if result.returncode or errors:
            raise RuntimeError(f"{label} failed ({result.returncode}): {errors}\nSee {output / (label + '.log')}")
        return result.stdout

    def probe_result(runtime):
        rows = [line.removeprefix("PACK_RESULT ") for line in runtime.splitlines() if line.startswith("PACK_RESULT ")]
        if len(rows) != 1:
            raise RuntimeError("Missing pack validation result")
        return json.loads(rows[0])

    run("import", "--editor", "--import")
    baseline = probe_result(run("play_source", "--", "debug"))
    if baseline["failures"] or baseline["clips"] != 2798:
        raise RuntimeError(f"Source baseline failed: {baseline}")
    results = []
    # Repeat a release export after debug to check export-cache isolation as well.
    for mode in ("release", "debug", "release_cached"):
        pack = output / (mode + ".pck")
        options = ["--export-pack", "Fixture", str(pack)]
        if mode == "debug":
            options.extend(["--export-debug", "Fixture"])
        run("export_" + mode, *options)
        runtime = run("play_" + mode, "--main-pack", str(pack), "--", "debug" if mode == "debug" else "release")
        result = probe_result(runtime)
        if result["failures"] or result["clips"] != 2798 or result["debug"] != (mode == "debug"):
            raise RuntimeError(f"Pack validation failed: {result}")
        results.append(result)
        if mode == "debug" and result["metadata"] != baseline["metadata"]:
            raise RuntimeError("Debug export changed source metadata")
        print(f"Verified {mode}: {result['clips']} clips, {result['aliases']} aliases", flush=True)
    for result in results:
        for key in ("motion", "pose", "aliases"):
            if result[key] != baseline[key]:
                raise RuntimeError(f"Debug and release differ in {key}")
    if {name: checksum(ROOT / name) for name in FILES} != before:
        raise RuntimeError("A development source file changed")
    print("PASS: release/debug/cached packs preserve motion, poses and aliases; development files unchanged.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
