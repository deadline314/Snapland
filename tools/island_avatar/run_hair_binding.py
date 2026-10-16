"""Run native hair pixel/actual-island acceptance, always with an isolated save."""
from pathlib import Path
import argparse
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.godot_entrypoints import run_validated_godot


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--quarter", action="store_true")
    parser.add_argument("--pixels", action="store_true")
    parser.add_argument("--style", choices=["windswept", "bob", "curly"], default="windswept")
    parser.add_argument("--pack", type=Path, help="Verify pixel rendering from an exported PCK")
    parser.add_argument("--reverse-only", action="store_true")
    parser.add_argument("--outfit-review", action="store_true", help="Also verify the native coral jacket sleeve during the bob tour")
    args = parser.parse_args()
    if args.outfit_review and (args.pixels or args.reverse_only or args.style != "bob"):
        raise ValueError("Outfit review requires a bob normal/quarter actual-island tour")
    if args.pack and (not args.pixels or not args.pack.is_file()):
        raise ValueError("An existing exported PCK and --pixels are required for pack verification")
    if not re.fullmatch(r"[a-z][a-z0-9-]{0,79}", args.tag):
        raise ValueError("Simple unique evidence tag required")
    output = ROOT / ".review/island-hair-binding" / args.tag
    if output.exists():
        raise ValueError("Preserve old evidence; choose another tag")
    output.mkdir(parents=True)
    env = dict(os.environ, SNAPLAND_SAVE_PATH=str(output / "profile/progress.json"),
               SNAPLAND_ISLAND_HAIR_DIR=str(output), SNAPLAND_ISLAND_HAIR_STYLE=args.style,
               SNAPLAND_ISLAND_HAIR_REQUIRE_PACK="1" if args.pack else "0",
               SNAPLAND_ISLAND_HAIR_QUARTER="1" if args.quarter else "0")
    engine = os.environ.get("GODOT_BIN") or shutil.which("godot4") or shutil.which("godot")
    if not engine:
        raise RuntimeError("Set GODOT_BIN to the actual project engine")
    launch_root = ROOT
    if args.pack:
        # A PCK mounted beside the source checkout can silently fall back to
        # loose PNGs. Probe from an empty project containing only this test.
        launch_root = output / "pack-project"
        launch_root.mkdir()
        (launch_root / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Snapland packed resource probe"\n')
        shutil.copy2(ROOT / "game/tests/test_island_hair_binding.gd", launch_root / "pixel_probe.gd")
    command = [engine, "--path", str(launch_root), "--audio-driver", "Dummy",
               "--rendering-method", "forward_plus", "--resolution", "640x360",
               "--log-file", str(output / "engine.log")]
    if args.pixels:
        if args.pack:
            # The probe stays outside the shipping pack; every game resource
            # it loads uses the PCK's res:// namespace and importer remaps.
            command += ["--main-pack", str(args.pack.resolve()), "--script", str(launch_root / "pixel_probe.gd")]
        else:
            command += ["--script", "res://game/tests/test_island_hair_binding.gd"]
    else:
        command += ["--fixed-fps", "30", "--write-movie", str(output / "movie.png"),
                    "res://game/tests/native_outfit_binding.tscn" if args.outfit_review else "res://game/tests/native_island_hair_binding.tscn"]
        if args.reverse_only:
            command += ["--", "--hair-reverse-only"]
    result = run_validated_godot(launch_root, command, env=env, timeout=600)
    log = result.stdout + "\n" + result.stderr
    (output / "run.log").write_text(log)
    if result.returncode or "ERROR:" in log or "SCRIPT ERROR" in log:
        raise RuntimeError(log[-5000:])
    audit = json.loads((output / "audit.json").read_text())
    expected = "PASS_NATIVE_ISLAND_HAIR_PIXELS" if args.pixels else "PASS_NATIVE_ISLAND_HAIR_BINDING"
    if audit["result"] != expected:
        raise RuntimeError("Acceptance failed: " + str(audit))
    if not args.pixels:
        ffmpeg = shutil.which("ffmpeg")
        if not ffmpeg:
            raise RuntimeError("ffmpeg required to preserve review movie")
        subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-framerate", "30",
                        "-i", str(output / "movie%08d.png"), "-an", "-c:v", "libx264", "-crf", "20",
                        "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(output / "review.mp4")], check=True)
        for frame in output.glob("movie????????.png"):
            frame.unlink()
    print(expected, output)


if __name__ == "__main__":
    main()
