"""Build a pinned Linux release from tracked runtime files in a private stage.

The template may live in a workspace; no shared Godot template installation is
modified. Output must be new, so existing builds and player profiles stay intact.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

from tools.godot_entrypoints import run_validated_godot

ROOT = Path(__file__).resolve().parents[1]
LINUX_TEMPLATE_SHA256 = "d9f79ab89b5ae369aeed11c6052d402e8218cd503bf85b4a235f9c30c46a7c63"


def prepare_runtime_stage(root: Path, stage: Path, tracked: list[str]) -> dict[str, str]:
    """Copy player resources without importing development-only test scripts.

    Export exclusions run after editor import. Tests may depend on authoring
    tools, which intentionally do not belong in a player build, so omit tests
    from the import stage too.
    """
    copied = {}
    for name in tracked:
        if not name:
            continue
        path = Path(name)
        if path.parts[:2] == ("game", "tests"):
            continue
        if path.parts[0] not in {"assets", "game"} and name not in {"project.godot", "export_presets.cfg", "design/01-park/park.json"}:
            continue
        source = root / path
        if source.is_file():
            destination = stage / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            copied[name] = hashlib.sha256(source.read_bytes()).hexdigest()
    return copied


def build(engine: Path, template: Path, output: Path) -> dict:
    if output.exists() and any(output.iterdir()):
        raise ValueError(f"Output must be an empty private directory: {output}")
    if not engine.is_file() or not template.is_file():
        raise ValueError("Provide the pinned Godot editor and Linux release template files")
    template_bytes = template.read_bytes()
    if hashlib.sha256(template_bytes).hexdigest() != LINUX_TEMPLATE_SHA256:
        raise ValueError("Provide the official Godot 4.7.2 Linux x86_64 release template; SHA256 mismatch")
    output.mkdir(parents=True, exist_ok=True)
    stage = output / "project"
    stage.mkdir()
    env = dict(os.environ, SNAPLAND_SAVE_PATH=str(output / "build-profile" / "progress.json"))
    version = run_validated_godot(ROOT, [str(engine), "--version"], env, 15)
    if version.returncode or not version.stdout.startswith("4.7.2.stable."):
        raise ValueError("Build requires Godot 4.7.2 stable, matching the export template")
    tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT, text=True).split("\0")
    copied = prepare_runtime_stage(ROOT, stage, tracked)
    presets = stage / "export_presets.cfg"
    text = presets.read_text()
    header, linux = text.split('[preset.1.options]', 1)
    template_path = str(template).replace('\\', '/')
    if '"' in template_path or '\n' in template_path:
        raise ValueError("Template path cannot contain quotes or newlines")
    linux = linux.replace('custom_template/release=""', f'custom_template/release="{template_path}"', 1)
    presets.write_text(header + '[preset.1.options]' + linux)
    release = output / "release"
    release.mkdir()
    binary = release / "Snapland.x86_64"
    results = []
    for label, args in [
        ("import", ["--editor", "--import", "--quit"]),
        ("export", ["--editor", "--export-release", "Linux Desktop", str(binary), "--quit"]),
    ]:
        start = time.monotonic()
        result = run_validated_godot(stage, [str(engine), "--headless", "--path", str(stage), *args], env, 300)
        log = result.stdout + result.stderr
        (output / f"{label}.log").write_text(log)
        results.append(dict(step=label, exit=result.returncode, errors=log.count("ERROR:"), seconds=round(time.monotonic()-start, 2)))
        if result.returncode or "ERROR:" in log:
            raise RuntimeError(f"{label} failed; see {output / (label + '.log')}")
    if not binary.is_file() or binary.stat().st_size <= template.stat().st_size or binary.read_bytes()[:4] != b"\x7fELF":
        raise RuntimeError("Export did not create the expected ELF with embedded game resources")
    binary.chmod(binary.stat().st_mode | 0o111)
    report = dict(
        engine=version.stdout.strip(),
        source_commit=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        template_sha256=hashlib.sha256(template.read_bytes()).hexdigest(),
        source_sha256=copied,
        steps=results,
        binary=dict(file=binary.name, bytes=binary.stat().st_size, sha256=hashlib.sha256(binary.read_bytes()).hexdigest()),
        scope="Linux x86_64 release executable with embedded PCK; runtime acceptance is a separate step",
    )
    (output / "build.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = build(args.godot.resolve(), args.template.resolve(), args.output.resolve())
    print("PASS: Linux release export", json.dumps(report["binary"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
