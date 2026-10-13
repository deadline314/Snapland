"""Validate Godot launch targets before spawning the engine."""
from __future__ import annotations

from pathlib import Path
import re
from collections.abc import Sequence
import os
import subprocess
from typing import Mapping


_EXTENDS = re.compile(r'^\s*extends\s+(?:"([^"]+)"|([A-Za-z_][A-Za-z0-9_.]*))\s*(?:#.*)?$')
_ENTRY_TYPES = {"SceneTree", "MainLoop"}
_SNAPSHOT_PARTS = {".review", "review", "commit-slices", "snapshots", "snapshot"}
_WINDOWS = os.name == "nt"


def validate_godot_command(root: str | Path, command: Sequence[str]) -> str | None:
    """Return an actionable launch error, or None when the command is structurally valid.

    This checks paths and GDScript base declarations only; it never starts Godot.
    """
    project = Path(root).resolve()
    args = [str(value) for value in command]
    if not args:
        return "Godot command is empty; provide an executable and a project launch target."
    if not (project / "project.godot").is_file():
        return f"Godot project file is missing from {project}; select the project directory containing project.godot."

    before_separator = args[: args.index("--")] if "--" in args else args
    script_arg: str | None = None
    scene_args: list[str] = []
    consumed: set[int] = set()
    explicit_project: str | None = None
    for index, arg in enumerate(before_separator):
        if index in consumed:
            continue
        if arg == "--script":
            if index + 1 >= len(before_separator):
                return "--script needs a project-local .gd entry script."
            if script_arg is not None:
                return "Specify only one --script entry; run additional tests separately."
            script_arg = before_separator[index + 1]
            consumed.add(index + 1)
        elif arg.startswith("--script="):
            if script_arg is not None:
                return "Specify only one --script entry; run additional tests separately."
            script_arg = arg.split("=", 1)[1]
        elif arg == "--path":
            if index + 1 >= len(before_separator):
                return "--path needs the Godot project directory."
            explicit_project = before_separator[index + 1]
            consumed.add(index + 1)
        elif arg.startswith("--path="):
            explicit_project = arg.split("=", 1)[1]
        elif arg == "--scene":
            if index + 1 >= len(before_separator):
                return "--scene needs a project-local .tscn scene."
            scene_args.append(before_separator[index + 1])
            consumed.add(index + 1)
        elif arg.startswith("--scene="):
            scene_args.append(arg.split("=", 1)[1])
        elif index > 0 and _has_suffix(arg, ".tscn"):
            scene_args.append(arg)
        elif index > 0 and _has_suffix(arg, ".gd"):
            if index not in consumed:
                return (
                    "A .gd file is not a scene entry. Run only a SceneTree/MainLoop test with --script; "
                    "run Node/Control scripts through their .tscn scene."
                )

    if explicit_project:
        project_arg = Path(explicit_project)
        if not project_arg.is_absolute():
            project_arg = Path.cwd() / project_arg
        if project_arg.resolve() != project:
            return f"Godot --path resolves to {project_arg.resolve()}, not the validated project {project}."

    if script_arg is not None and scene_args:
        return "A command cannot launch both --script and a scene; choose one entrypoint."
    is_import = "--editor" in before_separator and "--import" in before_separator
    if is_import:
        if script_arg is not None:
            return "--editor --import is a project parser launch and cannot be combined with --script."
        if scene_args:
            return "--editor --import cannot be combined with a runtime scene entry."
        return None

    if script_arg is not None:
        script_path, error = _resolve_project_file(project, script_arg, ".gd", "--script entry")
        if error:
            return error
        assert script_path is not None
        if _is_snapshot_path(project, script_path):
            return "Review snapshots are not runnable entries; keep them as text or launch a real test scene."
        return _validate_entry_script(project, script_path, set())

    if len(scene_args) > 1:
        return "Specify only one scene entry per Godot command."
    for scene in scene_args:
        _, error = _resolve_project_file(project, scene, ".tscn", "scene entry")
        if error:
            return error
    if not scene_args and "--editor" not in before_separator:
        return _validate_configured_main_scene(project)
    # Editor mode is not a runtime launch; import/parser mode only needs a project.
    return None


def run_validated_godot(
    root: str | Path,
    command: Sequence[str],
    env: Mapping[str, str] | None = None,
    timeout: float = 90.0,
) -> subprocess.CompletedProcess[str]:
    """Validate, then run one owned Godot process with a bounded timeout."""
    if timeout <= 0:
        raise ValueError("Godot timeout must be positive.")
    project = Path(root).resolve()
    args = [str(value) for value in command]
    error = validate_godot_command(project, args)
    if error:
        raise ValueError(error)
    process = subprocess.Popen(
        args,
        cwd=project,
        env=dict(env) if env is not None else None,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired as timeout_error:
        stdout, stderr = _stop_owned_process(process)
        raise subprocess.TimeoutExpired(
            args,
            timeout,
            output=_prefer_output(stdout, timeout_error.output),
            stderr=_prefer_output(stderr, timeout_error.stderr),
        ) from None
    return subprocess.CompletedProcess(args, process.returncode, stdout, stderr)


def _stop_owned_process(process: subprocess.Popen[str]) -> tuple[str, str]:
    if process.poll() is None:
        if _WINDOWS:
            try:
                subprocess.run(
                    ["taskkill", "/PID", str(process.pid), "/T", "/F"],
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                    timeout=5,
                    check=False,
                )
            except (OSError, subprocess.TimeoutExpired):
                pass
        else:
            try:
                process.terminate()
            except OSError:
                pass
    try:
        return process.communicate(timeout=3)
    except subprocess.TimeoutExpired as drain_error:
        if process.poll() is None:
            try:
                process.kill()
            except OSError:
                pass
        try:
            return process.communicate(timeout=5)
        except subprocess.TimeoutExpired as final_error:
            return (
                _prefer_output(final_error.output, drain_error.output),
                _prefer_output(final_error.stderr, drain_error.stderr),
            )


def _prefer_output(primary: str | bytes | None, fallback: str | bytes | None) -> str:
    value = primary if primary is not None else fallback
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return value or ""


def _has_suffix(value: str, suffix: str) -> bool:
    return value.lower().endswith(suffix)


def _resolve_project_file(project: Path, value: str, suffix: str, label: str) -> tuple[Path | None, str | None]:
    if not value:
        return None, f"{label} path is empty."
    if value.startswith("res://"):
        candidate = project / value[6:]
    else:
        candidate = Path(value)
        if not candidate.is_absolute():
            candidate = project / candidate
    resolved = candidate.resolve()
    try:
        resolved.relative_to(project)
    except ValueError:
        return None, f"{label} must stay inside the project: {value}"
    if resolved.suffix.lower() != suffix:
        return None, f"{label} must be a project-local {suffix} file: {value}"
    if not resolved.is_file():
        return None, f"{label} does not exist: {value}"
    return resolved, None


def _validate_configured_main_scene(project: Path) -> str | None:
    try:
        text = (project / "project.godot").read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        return f"Cannot read project.godot: {error}"
    match = re.search(r'(?m)^\s*run/main_scene\s*=\s*"([^"]+)"\s*(?:#.*)?$', text)
    if match is None:
        return "project.godot has no configured run/main_scene; select a .tscn scene or configure a valid main scene."
    _, error = _resolve_project_file(project, match.group(1), ".tscn", "Configured main scene")
    return error


def _is_snapshot_path(project: Path, path: Path) -> bool:
    relative = path.relative_to(project)
    parts = {part.lower() for part in relative.parts}
    stem = path.stem.lower()
    return bool(parts & _SNAPSHOT_PARTS) or "snapshot" in stem or "baseline" in stem


def _validate_entry_script(project: Path, path: Path, visited: set[Path]) -> str | None:
    if path in visited:
        return f"Entry script inheritance cycle detected at {path.relative_to(project)}."
    visited.add(path)
    try:
        source = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        return f"Cannot read entry script {path.relative_to(project)}: {error}"
    declaration = next((line.strip() for line in source.splitlines() if line.strip() and not line.lstrip().startswith("#")), "")
    match = _EXTENDS.match(declaration)
    if match is None:
        return f"Cannot verify a top-level extends declaration in {path.relative_to(project)}; use a SceneTree/MainLoop test entry."
    base_path, base_type = match.groups()
    if base_type in _ENTRY_TYPES:
        return None
    if base_path is None:
        return f"{path.relative_to(project)} extends {base_type}, not SceneTree/MainLoop; run its .tscn scene instead."
    base_value = base_path if base_path.startswith("res://") else str(path.parent / base_path)
    resolved_base, error = _resolve_project_file(project, base_value, ".gd", f"Base script for {path.relative_to(project)}")
    if error:
        return error
    assert resolved_base is not None
    if _is_snapshot_path(project, resolved_base):
        return f"Entry inheritance points into a review snapshot: {resolved_base.relative_to(project)}"
    return _validate_entry_script(project, resolved_base, visited)
