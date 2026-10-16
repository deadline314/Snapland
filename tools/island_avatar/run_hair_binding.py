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
    parser.add_argument("--reverse-only", action="store_true")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9-]{0,79}", args.tag):
        raise ValueError("Simple unique evidence tag required")
    output = ROOT / ".review/island-hair-binding" / args.tag
    if output.exists():
        raise ValueError("Preserve old evidence; choose another tag")
    output.mkdir(parents=True)
    env = dict(os.environ, SNAPLAND_SAVE_PATH=str(output / "profile/progress.json"),
               SNAPLAND_ISLAND_HAIR_DIR=str(output),
               SNAPLAND_ISLAND_HAIR_QUARTER="1" if args.quarter else "0")
    engine = os.environ.get("GODOT_BIN") or shutil.which("godot4") or shutil.which("godot")
    if not engine:
        raise RuntimeError("Set GODOT_BIN to the actual project engine")
    command = [engine, "--path", str(ROOT), "--audio-driver", "Dummy",
               "--rendering-method", "forward_plus", "--resolution", "640x360",
               "--log-file", str(output / "engine.log")]
    if args.pixels:
        command += ["--script", "res://game/tests/test_island_hair_binding.gd"]
    else:
        command += ["--fixed-fps", "30", "--write-movie", str(output / "movie.png"),
                    "res://game/tests/native_island_hair_binding.tscn"]
        if args.reverse_only:
            command += ["--", "--hair-reverse-only"]
    result = run_validated_godot(ROOT, command, env=env, timeout=600)
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
