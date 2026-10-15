"""Package and run the independent native 2D hero sample tour.

The normal and quarter-speed launches require a display/GPU. This script only
prepares the project when invoked; it is intentionally not run by repository
checks or import-time code.
"""
from __future__ import annotations

import argparse
from datetime import date
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
BUILD_ROOT = ROOT / "build"
PROJECT = BUILD_ROOT / "hero-2d-sample"
REVIEW_ROOT = ROOT / ".review" / f"hero-2d-sample-{date.today():%Y%m%d}"
ENGINE = os.environ.get("GODOT_BIN", "C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe")
EXPORT_DIR = BUILD_ROOT / "hero-2d-sample-release"
EXPORT_EXE = EXPORT_DIR / "Snapland-Hero-2D-Sample.exe"
PACK_RELATIVE = Path("assets") / "characters" / "hero-2d-v1"


def _listed_pack_files(pack: Path, manifest_path: Path) -> list[tuple[str, Path]]:
    """Resolve manifest files without allowing traversal or symlink escape."""
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"Cannot read valid hero 2D manifest {manifest_path}: {error}") from error
    if not isinstance(data, dict) or not isinstance(data.get("files"), list):
        raise SystemExit("Hero 2D manifest must provide a files[] list.")
    pack_root = pack.resolve()
    files: dict[str, Path] = {}
    for raw in data["files"]:
        if not isinstance(raw, str) or not raw.strip():
            raise SystemExit("Hero 2D manifest files[] entries must be non-empty relative paths.")
        relative = Path(raw.replace("\\", "/"))
        if relative.is_absolute() or relative.drive or ".." in relative.parts:
            raise SystemExit(f"Manifest file path escapes the character pack: {raw}")
        candidate = (pack / relative).resolve()
        try:
            candidate.relative_to(pack_root)
        except ValueError as error:
            raise SystemExit(f"Manifest file path escapes the character pack: {raw}") from error
        if not candidate.is_file():
            raise SystemExit(f"Manifest-listed compiled asset is missing: {candidate}")
        normalized = relative.as_posix()
        files[normalized] = candidate
    fallback = data.get("fallback", {})
    fallback_source = fallback.get("source") if isinstance(fallback, dict) else None
    if not isinstance(fallback_source, str) or fallback_source.replace("\\", "/") not in files:
        raise SystemExit("The complete fallback source must be present in manifest files[].")
    runtime_sources: set[str] = set()

    def collect_sources(value: object) -> None:
        if isinstance(value, dict):
            for key, child in value.items():
                if key == "source_record":
                    continue
                if key == "source" and isinstance(child, str):
                    runtime_sources.add(child.replace("\\", "/"))
                else:
                    collect_sources(child)
        elif isinstance(value, list):
            for child in value:
                collect_sources(child)

    for section in (data.get("poses", {}), data.get("hair", {}), data.get("hats", {}), fallback):
        collect_sources(section)
    undeclared = sorted(runtime_sources - set(files))
    if undeclared:
        raise SystemExit("Manifest image references must all be declared in files[]: " + ", ".join(undeclared[:8]))
    return sorted(files.items())


def prepare_project() -> Path:
    """Create a tiny Godot project with no Snapland autoloads."""
    assets = ROOT / "assets" / "characters" / "hero-2d-v1"
    manifest = assets / "manifest.json"
    if not manifest.is_file():
        raise SystemExit(f"Hero 2D manifest is not ready: {manifest}")
    listed_files = _listed_pack_files(assets, manifest)
    if not BUILD_ROOT.resolve().is_relative_to(ROOT.resolve()):
        raise SystemExit("Build directory escaped the repository root.")
    project_resolved = PROJECT.resolve()
    if not project_resolved.is_relative_to(BUILD_ROOT.resolve()):
        raise SystemExit("Sample project path escaped build/.")
    if PROJECT.exists():
        shutil.rmtree(PROJECT)
    PROJECT.mkdir(parents=True)
    for relative in [
        "game/review/hero_2d_sample.gd",
        "game/review/hero_2d_sample.tscn",
        "game/tests/native_hero_2d_sample.gd",
        "game/tests/native_hero_2d_sample.tscn",
        "game/world/hero_2d_pose.gd",
        "game/world/hero_2d_library.gd",
    ]:
        source = ROOT / relative
        if not source.is_file():
            raise SystemExit(f"Required sample source is missing: {source}")
        target = PROJECT / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    pack_destination = PROJECT / PACK_RELATIVE
    pack_destination.mkdir(parents=True, exist_ok=True)
    shutil.copy2(manifest, pack_destination / "manifest.json")
    for relative, source in listed_files:
        target = pack_destination / Path(relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    (PROJECT / "project.godot").write_text(
        '[application]\n'
        'config/name="Snapland Hero 2D Sample"\n'
        'run/main_scene="res://game/review/hero_2d_sample.tscn"\n'
        'config/features=PackedStringArray("4.7", "GL Compatibility")\n'
        '\n[display]\n'
        'window/size/viewport_width=1280\n'
        'window/size/viewport_height=800\n'
        'window/stretch/mode="canvas_items"\n'
        '\n[rendering]\n'
        'renderer/rendering_method="gl_compatibility"\n'
        'textures/default_filters/use_nearest_mipmap_filter=false\n'
        'textures/default_filters/texture_filter=0\n',
        encoding="utf-8",
    )
    (PROJECT / "export_presets.cfg").write_text(
        '[preset.0]\n'
        'name="Snapland Hero 2D Sample"\n'
        'platform="Windows Desktop"\n'
        'runnable=true\n'
        'advanced_options=false\n'
        'dedicated_server=false\n'
        'custom_features=""\n'
        'export_filter="all_resources"\n'
        'include_filter="assets/characters/hero-2d-v1/manifest.json,assets/characters/hero-2d-v1/compiled/*.png"\n'
        'exclude_filter="game/tests/*,tools/*"\n'
        'export_path="../hero-2d-sample-release/Snapland-Hero-2D-Sample.exe"\n'
        'script_export_mode=2\n'
        '\n[preset.0.options]\n'
        'custom_template/debug=""\n'
        'custom_template/release=""\n'
        'debug/export_console_wrapper=1\n'
        'binary_format/embed_pck=true\n'
        'binary_format/architecture="x86_64"\n'
        'application/modify_resources=false\n',
        encoding="utf-8",
    )
    return PROJECT


def _isolated_environment(out_dir: Path, quarter: bool) -> dict[str, str]:
    home = out_dir / ("isolated-user-home-" + uuid.uuid4().hex[:10])
    appdata = home / "AppData" / "Roaming"
    local_appdata = home / "AppData" / "Local"
    temporary = home / "Temp"
    for directory in [home, appdata, local_appdata, temporary, out_dir]:
        directory.mkdir(parents=True, exist_ok=True)
    home_path = str(home)
    env = os.environ.copy()
    env.update(
        {
            "SNAPLAND_SAVE_PATH": str(out_dir / "isolated-save.json"),
            "SNAPLAND_HERO_2D_REVIEW_DIR": str(out_dir),
            "SNAPLAND_HERO_2D_QUARTER": "1" if quarter else "0",
            "USERPROFILE": str(home),
            "HOME": str(home),
            "HOMEDRIVE": home.drive,
            "HOMEPATH": home_path[len(home.drive):],
            "APPDATA": str(appdata),
            "LOCALAPPDATA": str(local_appdata),
            "TEMP": str(temporary),
            "TMP": str(temporary),
            "XDG_CONFIG_HOME": str(home / ".config"),
            "XDG_DATA_HOME": str(home / ".local" / "share"),
        }
    )
    return env


def _run_one(project: Path, tag: str, quarter: bool, no_movie: bool, timeout: float) -> None:
    from tools.godot_entrypoints import run_validated_godot

    out_dir = REVIEW_ROOT / tag
    if out_dir.exists():
        review_root = REVIEW_ROOT.resolve()
        resolved_output = out_dir.resolve()
        history = REVIEW_ROOT / "history" / (tag + "-" + uuid.uuid4().hex[:10])
        if resolved_output == review_root or not resolved_output.is_relative_to(review_root) or not history.resolve().is_relative_to(review_root):
            raise SystemExit("Review archive path escaped the isolated review directory.")
        history.parent.mkdir(parents=True, exist_ok=True)
        out_dir.rename(history)
    out_dir.mkdir(parents=True, exist_ok=True)
    env = _isolated_environment(out_dir, quarter)
    engine = os.environ.get("GODOT_BIN", ENGINE)
    import_args = [engine, "--headless", "--path", str(project), "--editor", "--import"]
    imported = run_validated_godot(project, import_args, env=env, timeout=300.0)
    import_log = imported.stdout + "\n" + imported.stderr
    (out_dir / "import.log").write_text(import_log, encoding="utf-8")
    if imported.returncode != 0 or "SCRIPT ERROR" in import_log or "ERROR:" in import_log:
        raise SystemExit(f"Godot import failed; inspect {out_dir / 'import.log'}")

    movie_sequence = out_dir / "movie.png"
    command = [
        engine, "--path", str(project), "--resolution", "1280x800", "--fixed-fps", "30",
        "--scene", "res://game/tests/native_hero_2d_sample.tscn",
    ]
    if not no_movie:
        command.extend(["--write-movie", str(movie_sequence)])
    result = run_validated_godot(project, command, env=env, timeout=timeout)
    log = result.stdout + "\n" + result.stderr
    (out_dir / "run.log").write_text(log, encoding="utf-8")
    print(f"[{tag}] {log[-2200:]}")
    if result.returncode != 0 or "SCRIPT ERROR" in log or "ERROR:" in log:
        raise SystemExit(f"Native sample failed; inspect {out_dir / 'run.log'}")
    audit_path = out_dir / "audit.json"
    if not audit_path.is_file():
        raise SystemExit(f"Native scene did not produce its audit: {audit_path}")
    audit = json.loads(audit_path.read_text(encoding="utf-8"))
    checks = audit.get("checks", {})
    missing = [name for name, passed in checks.items() if passed is not True]
    inputs = audit.get("native_input_events", {})
    if audit.get("result") != "PASS_STATE_CHECKS" or missing:
        raise SystemExit(f"State checks failed ({', '.join(missing) or audit.get('failures')}); inspect {audit_path}")
    if int(inputs.get("keys", 0)) <= 0 or int(inputs.get("mouse_buttons", 0)) <= 0:
        raise SystemExit(f"Tour did not prove both keyboard and mouse input events: {audit_path}")
    if no_movie:
        print(f"[{tag}] State checks passed; visual captures still require human review.")
        return
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise SystemExit("ffmpeg is required to encode the native Godot frame sequence to MP4.")
    movie_path = out_dir / f"hero-2d-{tag}.mp4"
    subprocess.run(
        [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-framerate", "30", "-i",
         str(out_dir / "movie%08d.png"), "-an", "-c:v", "libx264", "-crf", "18",
         "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(movie_path)],
        check=True,
    )
    for frame_path in out_dir.glob("movie[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].png"):
        frame_path.unlink()
    print(f"[{tag}] Video: {movie_path}")
    print(f"[{tag}] Review the frames and video visually; state checks are not an art pass.")


def _export_sample(project: Path, timeout: float, smoke: bool) -> None:
    from tools.godot_entrypoints import run_validated_godot

    engine = os.environ.get("GODOT_BIN", ENGINE)
    template_root = Path(os.environ.get("APPDATA", str(Path.home() / "AppData" / "Roaming")))
    templates = template_root / "Godot" / "export_templates" / "4.7.2.stable"
    required_templates = [templates / "windows_release_x86_64.exe", templates / "windows_release_x86_64_console.exe"]
    missing = [str(path) for path in required_templates if not path.is_file()]
    if missing:
        raise SystemExit("Godot 4.7.2 Windows export templates are missing: " + ", ".join(missing))
    if not EXPORT_DIR.resolve().is_relative_to(BUILD_ROOT.resolve()):
        raise SystemExit("Windows export destination escaped build/.")
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    out_dir = REVIEW_ROOT / "export"
    out_dir.mkdir(parents=True, exist_ok=True)
    env = _isolated_environment(out_dir, quarter=False)
    # Godot locates installed export templates through APPDATA; keep save and review
    # outputs isolated while exposing only the configured template directory.
    env["APPDATA"] = str(template_root)
    import_result = run_validated_godot(
        project,
        [engine, "--headless", "--path", str(project), "--editor", "--import"],
        env=env,
        timeout=min(timeout, 300.0),
    )
    import_log = import_result.stdout + "\n" + import_result.stderr
    (out_dir / "import.log").write_text(import_log, encoding="utf-8")
    if import_result.returncode != 0 or "SCRIPT ERROR" in import_log or "ERROR:" in import_log:
        raise SystemExit(f"Godot import failed; inspect {out_dir / 'import.log'}")
    export_result = run_validated_godot(
        project,
        [engine, "--headless", "--path", str(project), "--export-release", "Snapland Hero 2D Sample", str(EXPORT_EXE)],
        env=env,
        timeout=timeout,
    )
    export_log = export_result.stdout + "\n" + export_result.stderr
    (out_dir / "export.log").write_text(export_log, encoding="utf-8")
    if export_result.returncode != 0 or "SCRIPT ERROR" in export_log or "ERROR:" in export_log or not EXPORT_EXE.is_file() or EXPORT_EXE.stat().st_size == 0:
        raise SystemExit(f"Windows export failed; inspect {out_dir / 'export.log'}")
    print(f"Embedded-PCK Windows executable: {EXPORT_EXE}")
    if not smoke:
        return
    smoke_dir = out_dir / "startup-smoke"
    smoke_dir.mkdir(parents=True, exist_ok=True)
    env["SNAPLAND_HERO_2D_REVIEW_DIR"] = str(smoke_dir)
    env["SNAPLAND_SAVE_PATH"] = str(smoke_dir / "isolated-save.json")
    smoke_result = run_validated_godot(
        project,
        [str(EXPORT_EXE), "--fixed-fps", "30", "--write-movie", str(smoke_dir / "startup.png"), "--quit-after", "1"],
        env=env,
        timeout=min(timeout, 120.0),
    )
    smoke_log = smoke_result.stdout + "\n" + smoke_result.stderr
    (smoke_dir / "launch.log").write_text(smoke_log, encoding="utf-8")
    captures = list(smoke_dir.glob("startup*.png"))
    if smoke_result.returncode != 0 or "SCRIPT ERROR" in smoke_log or "ERROR:" in smoke_log or not captures:
        raise SystemExit(f"Exported executable startup/frame capture failed; inspect {smoke_dir / 'launch.log'}")
    (smoke_dir / "scope.txt").write_text(
        "Exported executable launched and captured its configured interactive main scene for one frame. "
        "This does not simulate controls or constitute a visual/interaction acceptance pass.\n",
        encoding="utf-8",
    )
    print(f"Startup capture only (no control simulation): {captures[0]}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--prepare-only", action="store_true", help="Stage the isolated project and export preset without launching Godot.")
    group.add_argument("--export-only", action="store_true", help="Import and export the embedded-PCK Windows sample, without running the native tour.")
    group.add_argument("--normal-only", action="store_true")
    group.add_argument("--quarter-only", action="store_true")
    parser.add_argument("--smoke-export", action="store_true", help="Optionally launch the export for one frame and save a startup capture; controls are not simulated.")
    parser.add_argument("--no-movie", action="store_true", help="Keep PNG captures and audit without Godot movie recording.")
    parser.add_argument("--timeout", type=float, default=600.0)
    args = parser.parse_args()
    if args.timeout <= 0:
        raise SystemExit("--timeout must be positive.")
    project = prepare_project()
    if args.prepare_only:
        print(f"Prepared isolated sample project: {project}")
        return
    if args.export_only:
        smoke = args.smoke_export or os.environ.get("SNAPLAND_HERO_2D_SMOKE_EXPORT") == "1"
        _export_sample(project, args.timeout, smoke)
        return
    if args.smoke_export:
        parser.error("--smoke-export requires --export-only.")
    cases = [("normal", False), ("quarter", True)]
    if args.normal_only:
        cases = cases[:1]
    elif args.quarter_only:
        cases = cases[1:]
    for tag, quarter in cases:
        _run_one(project, tag, quarter, args.no_movie, args.timeout)


if __name__ == "__main__":
    main()
