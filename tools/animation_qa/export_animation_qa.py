"""Prepare and safely export an isolated Windows animation QA package.

The helper never edits the source project's release preset. It creates a
sanitized temporary project inside one caller-selected, new output directory,
then invokes Godot only through tools.godot_entrypoints.run_validated_godot.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PRESET = Path(__file__).with_name("animation-qa-export-presets.cfg")
PRESET_NAME = "Snapland Animation QA Windows"
FIXTURE_FILES = {
    "game/tests/native_island_animation_acceptance.gd",
    "game/tests/native_island_animation_acceptance.tscn",
    "game/tests/native_island_animation_acceptance.gd.uid",
}
RELEASE_JSON = {
    "design/01-park/park.json",
    "assets/minigames/props/regions.json",
    "assets/world/foliage-regions.json",
}


def _selected_project_file(relative: Path) -> bool:
    rel = relative.as_posix()
    if rel == "project.godot" or rel == "export_presets.cfg":
        return True
    if rel.startswith("assets/") or rel.startswith("game/"):
        if rel.startswith("game/tests/"):
            return rel in FIXTURE_FILES
        return True
    if rel in RELEASE_JSON or rel == "assets/characters/complete-animation-regions.json":
        return True
    if rel.startswith("game/data/") and rel.endswith(".json"):
        return True
    if rel.startswith("assets/characters/") and rel.endswith(".json"):
        return True
    return False


def prepare_project(destination: Path) -> dict[str, object]:
    project = destination / "qa-project"
    if project.exists():
        raise FileExistsError(f"Refusing to reuse existing QA project: {project}")
    project.mkdir(parents=True)
    copied: list[str] = []
    for source in ROOT.rglob("*"):
        if not source.is_file():
            continue
        try:
            relative = source.relative_to(ROOT)
        except ValueError:
            continue
        parts = relative.parts
        if any(part in {".git", ".godot", ".review"} for part in parts):
            continue
        if parts[0] in {"pm", "tests", "tools", ".private", ".agents", ".claude"}:
            continue
        if parts[0] == "design" and relative.as_posix() != "design/01-park/park.json":
            continue
        if not _selected_project_file(relative):
            continue
        target = project / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        copied.append(relative.as_posix())

    expected = {"project.godot", "game/main.tscn", "design/01-park/park.json", "game/tests/native_island_animation_acceptance.gd", "game/tests/native_island_animation_acceptance.tscn"}
    missing = sorted(path for path in expected if path not in copied)
    if missing:
        raise FileNotFoundError("Required QA project files were not copied: " + ", ".join(missing))
    preset_text = PRESET.read_text(encoding="utf-8")
    (project / "export_presets.cfg").write_text(preset_text, encoding="utf-8", newline="\n")

    project_file = project / "project.godot"
    project_text = project_file.read_text(encoding="utf-8")
    main_scene = 'run/main_scene="res://game/main.tscn"'
    qa_scene = 'run/main_scene="res://game/tests/native_island_animation_acceptance.tscn"'
    if main_scene not in project_text:
        raise ValueError("Could not find expected release main-scene setting in copied project.godot")
    project_file.write_text(project_text.replace(main_scene, qa_scene, 1), encoding="utf-8", newline="\n")
    return {
        "project": str(project),
        "fixture": "res://game/tests/native_island_animation_acceptance.tscn",
        "preset": PRESET_NAME,
        "copied_file_count": len(copied),
        "included_tests": sorted(path for path in copied if path.startswith("game/tests/")),
        "excluded_groups": ["pm/", "design/runtime/", ".review/", "tools/", "tests/", "all other game/tests/"],
        "source_release_preset_modified": False,
        "included_runtime_json": sorted(path for path in copied if path.endswith(".json")),
        "included_fonts": sorted(path for path in copied if Path(path).suffix.lower() in {".ttf", ".otf", ".woff", ".woff2"}),
        "included_licenses": sorted(path for path in copied if path.endswith(".txt") and (path.startswith("assets/fonts/") or path.startswith("assets/audio/cc0/licenses/"))),
        "note": "Preparation checks copied files only; compilation and native playback require separate engine launches.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", required=True, type=Path, help="new, empty directory for the QA project and package")
    parser.add_argument("--godot-bin", default=os.environ.get("GODOT_BIN", ""), help="Godot 4.7.2 executable; defaults to GODOT_BIN")
    parser.add_argument("--prepare-only", action="store_true", help="create and inspect the sanitized QA project without exporting")
    parser.add_argument("--timeout", type=int, default=600, help="bounded export timeout in seconds")
    args = parser.parse_args()
    output = args.output_dir.expanduser().resolve()
    if output == ROOT or ROOT in output.parents:
        parser.error("output directory must be outside the source project")
    if output.exists() and any(output.iterdir()):
        parser.error(f"output directory must be new or empty: {output}")
    output.mkdir(parents=True, exist_ok=True)
    info = prepare_project(output)
    (output / "qa-export-plan.json").write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(info, indent=2))
    if args.prepare_only:
        return 0
    if not args.godot_bin:
        parser.error("provide --godot-bin or set GODOT_BIN")
    try:
        version = subprocess.run([args.godot_bin, "--version"], check=True, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30)
    except (OSError, subprocess.SubprocessError) as error:
        parser.error(f"cannot query Godot executable: {error}")
    version_text = version.stdout + version.stderr
    if "4.7.2" not in version_text:
        parser.error(f"expected Godot 4.7.2, received {version_text.strip()!r}")

    sys.path.insert(0, str(ROOT))
    from tools.godot_entrypoints import run_validated_godot

    project = Path(str(info["project"]))
    package = output / "Snapland-animation-qa.exe"
    command = [args.godot_bin, "--headless", "--path", str(project), "--export-release", PRESET_NAME, str(package)]
    result = run_validated_godot(project, command, timeout=args.timeout)
    (output / "godot-export.log").write_text(result.stdout + result.stderr, encoding="utf-8")
    if result.returncode:
        print(f"Godot export failed with exit {result.returncode}; see {output / 'godot-export.log'}", file=sys.stderr)
        return result.returncode
    if not package.is_file():
        print("Godot reported success but no QA executable was created.", file=sys.stderr)
        return 1
    print(f"QA package created: {package}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
