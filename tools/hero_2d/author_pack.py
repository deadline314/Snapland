"""Compile explicit 2D authored cels and attachment layers into runtime atlases."""
from __future__ import annotations

from collections import deque
import json
import math
from pathlib import Path
from typing import Any

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "assets/characters/hero-2d-v1"
DIRECTIONS = ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
ACTIONS = ["idle", "start", "walk", "stop", "turn", "photo"]
CANVAS = (280, 360)
FEET = (140, 346)
PART_CELL = (160, 160)
PART_ANCHOR = (80, 80)
_MODEL_SUFFIXES = {".blend", ".glb", ".gltf", ".fbx", ".obj", ".dae"}


def clean_alpha(image: Image.Image) -> Image.Image:
    """Clear near-transparent source pixels without recoloring the authored art."""
    result = image.convert("RGBA")
    result.putalpha(result.getchannel("A").point(lambda value: 0 if value < 8 else value))
    return result


def clean_part(image: Image.Image) -> Image.Image:
    """Keep the largest 8-connected opaque component in one authored part cel."""
    result = clean_alpha(image)
    width, height = result.size
    alpha = result.getchannel("A")
    source_alpha = alpha.copy()
    visited = bytearray(width * height)
    largest: list[int] = []
    for y in range(height):
        for x in range(width):
            start = y * width + x
            if visited[start] or alpha.getpixel((x, y)) == 0:
                continue
            visited[start] = 1
            queue = deque([start])
            component: list[int] = []
            while queue:
                index = queue.popleft()
                component.append(index)
                px, py = index % width, index // width
                for ny in range(max(0, py - 1), min(height, py + 2)):
                    for nx in range(max(0, px - 1), min(width, px + 2)):
                        neighbor = ny * width + nx
                        if not visited[neighbor] and alpha.getpixel((nx, ny)) > 0:
                            visited[neighbor] = 1
                            queue.append(neighbor)
            if len(component) > len(largest):
                largest = component
    if not largest:
        result.putalpha(Image.new("L", result.size, 0))
        return result
    keep = bytearray(width * height)
    for index in largest:
        keep[index] = 255
    retained_alpha = Image.new("L", result.size)
    retained_alpha.putdata(
        [
            source_alpha.getpixel((index % width, index // width)) if keep[index] else 0
            for index in range(width * height)
        ]
    )
    result.putalpha(retained_alpha)
    return result


def clip_hat_part(image: Image.Image, clip_y: int) -> Image.Image:
    """Return an explicit under-hat variant with pixels above clip_y removed."""
    if not isinstance(clip_y, int) or clip_y < 0 or clip_y > image.height:
        raise ValueError("hat_clip_y must be an integer within the compiled part cell")
    result = image.convert("RGBA").copy()
    if clip_y:
        alpha = result.getchannel("A")
        for y in range(clip_y):
            alpha.paste(0, (0, y, result.width, y + 1))
        result.putalpha(alpha)
    return result


def _validate_hat_clear_regions(value: Any, context: str, cell_size: tuple[int, int] = PART_CELL) -> list[tuple[int, int, int, int]]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise ValueError(f"{context} hat_clear_regions must be a list of canonical rectangles")
    regions: list[tuple[int, int, int, int]] = []
    for rect in value:
        if not isinstance(rect, list) or len(rect) != 4 or any(not isinstance(number, int) for number in rect):
            raise ValueError(f"{context} hat clear region must be integer [x,y,w,h]")
        x, y, width, height = rect
        if x < 0 or y < 0 or width <= 0 or height <= 0 or x + width > cell_size[0] or y + height > cell_size[1]:
            raise ValueError(f"{context} hat clear region must fit the canonical {cell_size[0]}×{cell_size[1]} part cell")
        regions.append((x, y, width, height))
    return regions


def _part_canvas(value: Any) -> tuple[int, int]:
    if value is None:
        return PART_CELL
    if not isinstance(value, list) or len(value) != 2 or any(not isinstance(number, int) or number <= 0 or number % 2 for number in value):
        raise ValueError("part_canvas must be an even positive integer [width,height]")
    return value[0], value[1]


def _compile_part_record(record: dict[str, Any], pack: Path, cell_size: tuple[int, int], context: str, *, preserve_components: bool = False) -> Image.Image:
    if not isinstance(record, dict):
        raise ValueError(f"{context} record must be an object")
    source_path = _pack_path(pack, str(record.get("source", "")))
    with Image.open(source_path) as opened:
        source = clean_alpha(opened)
    x, y, width, height = _region(record.get("region"), source.size, context)
    return compile_part_cell(
        source.crop((x, y, x + width, y + height)),
        record.get("anchor"),
        record.get("scale"),
        record.get("offset"),
        cell_size,
        preserve_components=preserve_components,
    )


def clear_hat_regions(image: Image.Image, regions: list[tuple[int, int, int, int]]) -> Image.Image:
    """Clear reviewed pixels from the under-hat variant without touching regular hair."""
    result = image.convert("RGBA").copy()
    alpha = result.getchannel("A")
    for x, y, width, height in regions:
        alpha.paste(0, (x, y, x + width, y + height))
    result.putalpha(alpha)
    return result


def _pack_path(pack: Path, relative: str) -> Path:
    candidate = Path(relative)
    if candidate.is_absolute():
        raise ValueError(f"source must be pack-relative: {relative}")
    resolved = (pack / candidate).resolve()
    try:
        resolved.relative_to(pack.resolve())
    except ValueError as error:
        raise ValueError(f"source escapes the pack root: {relative}") from error
    if not resolved.is_file():
        raise ValueError(f"source file is missing: {relative}")
    return resolved


def _number_pair(value: Any, context: str) -> tuple[float, float]:
    if not isinstance(value, list) or len(value) != 2:
        raise ValueError(f"{context} must be a numeric [x,y] pair")
    if any(not isinstance(part, (int, float)) or not math.isfinite(float(part)) for part in value):
        raise ValueError(f"{context} must contain finite numbers")
    return float(value[0]), float(value[1])


def _region(value: Any, source_size: tuple[int, int], context: str) -> tuple[int, int, int, int]:
    if not isinstance(value, list) or len(value) != 4 or any(not isinstance(part, int) for part in value):
        raise ValueError(f"{context} region must be integer [x,y,w,h]")
    x, y, width, height = value
    if x < 0 or y < 0 or width <= 0 or height <= 0 or x + width > source_size[0] or y + height > source_size[1]:
        raise ValueError(f"{context} region is outside its source image")
    return x, y, width, height


def _finite_scale(value: Any, context: str) -> float:
    if not isinstance(value, (int, float)) or not math.isfinite(float(value)) or value <= 0:
        raise ValueError(f"{context} scale must be a positive finite number")
    return float(value)


def _record_image(record: dict[str, Any], pack: Path, context: str) -> tuple[Image.Image, float, tuple[float, float], tuple[float, float]]:
    if not isinstance(record, dict):
        raise ValueError(f"{context} record must be an object")
    source = str(record.get("source", ""))
    source_path = _pack_path(pack, source)
    with Image.open(source_path) as opened:
        image = clean_alpha(opened)
    x, y, width, height = _region(record.get("region"), image.size, context)
    scale = _finite_scale(record.get("scale"), context)
    head_anchor = _number_pair(record.get("head_anchor"), f"{context} head_anchor")
    feet = _number_pair(record.get("feet"), f"{context} feet")
    return image.crop((x, y, x + width, y + height)), scale, head_anchor, feet


def source_frame(record: dict[str, Any], pack: Path = PACK) -> tuple[Image.Image, tuple[int, int]]:
    """Crop a reviewed full-body record and normalize its feet/head anchors."""
    crop, scale, head_anchor, feet = _record_image(record, pack, "pose")
    size = (round(crop.width * scale), round(crop.height * scale))
    if min(size) <= 0:
        raise ValueError("pose scale collapses the source region")
    resized = crop.resize(size, Image.Resampling.NEAREST)
    offset = (round(FEET[0] - feet[0] * scale), round(FEET[1] - feet[1] * scale))
    canvas = Image.new("RGBA", CANVAS)
    canvas.alpha_composite(resized, offset)
    guide = (round(head_anchor[0] * scale + offset[0]), round(head_anchor[1] * scale + offset[1]))
    attachment = _number_pair(record.get("head_attachment_offset", [0, 0]), "pose head_attachment_offset")
    head = tuple(guide[i] + round(attachment[i]) for i in range(2))
    return canvas, head


def compile_part_cell(
    image: Image.Image,
    anchor: list[float],
    scale: float,
    offset: list[int] | None = None,
    cell_size: tuple[int, int] = PART_CELL,
    *,
    preserve_components: bool = False,
) -> Image.Image:
    """Normalize one authored part into its centered atlas cell."""
    anchor_x, anchor_y = _number_pair(anchor, "part anchor")
    scale = _finite_scale(scale, "part")
    if offset is not None:
        _number_pair(offset, "part offset")  # Layer offsets are applied by the runtime, not baked into the cel.
    resized = clean_alpha(image).resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))), Image.Resampling.NEAREST)
    cell_anchor = (cell_size[0] // 2, cell_size[1] // 2)
    placement = (round(cell_anchor[0] - anchor_x * scale), round(cell_anchor[1] - anchor_y * scale))
    cell = Image.new("RGBA", cell_size)
    cell.alpha_composite(resized, placement)
    return clean_alpha(cell) if preserve_components else clean_part(cell)


def _validate_foreground_regions(value: Any, context: str) -> list[list[int]]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise ValueError(f"{context} foreground_regions must be a list of canonical rectangles")
    result: list[list[int]] = []
    for rect in value:
        if not isinstance(rect, list) or len(rect) != 4 or any(not isinstance(number, int) for number in rect):
            raise ValueError(f"{context} foreground region must be integer [x,y,w,h]")
        x, y, width, height = rect
        if x < 0 or y < 0 or width <= 0 or height <= 0 or x + width > CANVAS[0] or y + height > CANVAS[1]:
            raise ValueError(f"{context} foreground region must fit the canonical 280×360 cel")
        result.append(list(rect))
    return result


def _copy_record(record: dict[str, Any]) -> dict[str, Any]:
    return json.loads(json.dumps(record))


def _pose_records(data: dict[str, Any]) -> tuple[dict[str, dict[str, list[dict[str, Any]]]], list[str]]:
    walk = data.get("walk")
    actions = data.get("actions", {})
    if not isinstance(walk, dict) or not isinstance(actions, dict):
        raise ValueError("authoring.json requires walk[direction] and actions[direction][action]")
    action_names = set(ACTIONS)
    merged: dict[str, dict[str, list[dict[str, Any]]]] = {}
    for direction in DIRECTIONS:
        if direction not in walk or not isinstance(walk[direction], list) or not walk[direction]:
            raise ValueError(f"walk/{direction} must contain at least one authored frame")
        direction_actions: dict[str, list[dict[str, Any]]] = {"walk": walk[direction]}
        action_value = actions.get(direction, {})
        if not isinstance(action_value, dict):
            raise ValueError(f"actions/{direction} must be an object")
        for action, frames in action_value.items():
            if action == "walk":
                raise ValueError(f"walk/{direction} must be declared only under the walk table")
            if action not in ACTIONS:
                raise ValueError(f"actions/{direction}/{action} is not a supported runtime action")
            if not isinstance(frames, list) or not frames:
                raise ValueError(f"actions/{direction}/{action} must contain at least one authored frame")
            direction_actions[action] = frames
            action_names.add(action)
        merged[direction] = direction_actions
    expected_actions = set(merged[DIRECTIONS[0]])
    for direction in DIRECTIONS[1:]:
        if set(merged[direction]) != expected_actions:
            raise ValueError(f"actions/{direction} coverage must match {DIRECTIONS[0]}")
    missing = set(ACTIONS) - set.intersection(*(set(merged[direction]) for direction in DIRECTIONS))
    if missing:
        raise ValueError("authoring data is missing action coverage: " + ", ".join(sorted(missing)))
    return merged, sorted(action_names, key=lambda name: ACTIONS.index(name) if name in ACTIONS else len(ACTIONS) + len(name))


def _compile_poses(data: dict[str, Any], pack: Path, output_dir: Path) -> tuple[dict[str, dict[str, list[dict[str, Any]]]], list[str]]:
    records_by_direction, action_names = _pose_records(data)
    poses: dict[str, dict[str, list[dict[str, Any]]]] = {direction: {} for direction in DIRECTIONS}
    compiled_files: list[str] = []
    stable = data.get("stable_head_parts", {})
    stable_refs = {}
    seam = 0
    if stable:
        seam = int(stable["seam_y"])
        if not 180 <= seam <= 210 or stable.get("head_anchor") != [140, 148]:
            raise ValueError("Head/neck part must use the reviewed seam and canonical head anchor")
        for heading in DIRECTIONS:
            first = records_by_direction[heading]["walk"][0]
            for outfit, rec in [("tide_jacket", first), ("long_coat", first["outfits"]["long_coat"])]:
                reference, _ = source_frame(rec, pack)
                stable_refs[(heading, outfit)] = reference.crop((0, 0, CANVAS[0], int(stable.get("seams_by_heading", {}).get(heading, seam))))
    for action in action_names:
        max_frames = max(len(records_by_direction[direction][action]) for direction in DIRECTIONS)
        body_atlas = Image.new("RGBA", (CANVAS[0] * max_frames, CANVAS[1] * len(DIRECTIONS)))
        coat_atlas = Image.new("RGBA", body_atlas.size)
        body_name = f"compiled/tide-{action}.png"
        coat_name = f"compiled/coat-{action}.png"
        for row, direction in enumerate(DIRECTIONS):
            for col, record in enumerate(records_by_direction[direction][action]):
                body, head = source_frame(record, pack)
                body_guide = [head[i] - round(record.get("head_attachment_offset", [0, 0])[i]) for i in range(2)]
                if stable and action in stable["actions"]:
                    body.paste(stable_refs[(direction, "tide_jacket")], (0, 0))
                    head = tuple(stable["head_anchor"])
                origin = (col * CANVAS[0], row * CANVAS[1])
                body_atlas.alpha_composite(body, origin)
                frame: dict[str, Any] = {
                    "source": body_name,
                    "region": [origin[0], origin[1], CANVAS[0], CANVAS[1]],
                    "head_anchor": list(head),
                    "body_guide": body_guide,
                    "feet": list(FEET),
                    "source_record": _copy_record(record),
                }
                foreground = _validate_foreground_regions(record.get("foreground_regions", []), f"{direction}/{action}")
                if foreground:
                    frame["foreground_regions"] = foreground
                coat_record = record.get("outfits", {}).get("long_coat") if isinstance(record.get("outfits", {}), dict) else None
                if coat_record is not None:
                    coat, coat_head = source_frame(coat_record, pack)
                    coat_guide = [coat_head[i] - round(coat_record.get("head_attachment_offset", [0, 0])[i]) for i in range(2)]
                    if stable and action in stable["actions"]:
                        coat.paste(stable_refs[(direction, "long_coat")], (0, 0))
                        coat_head = tuple(stable["head_anchor"])
                    coat_atlas.alpha_composite(coat, origin)
                    outfit = {
                        "source": coat_name,
                        "region": [origin[0], origin[1], CANVAS[0], CANVAS[1]],
                        "head_anchor": list(coat_head),
                        "body_guide": coat_guide,
                        "feet": list(FEET),
                        "source_record": _copy_record(coat_record),
                    }
                    coat_foreground = _validate_foreground_regions(coat_record.get("foreground_regions", []), f"{direction}/{action}/long_coat")
                    if coat_foreground:
                        outfit["foreground_regions"] = coat_foreground
                    frame["outfits"] = {"long_coat": outfit}
                poses[direction].setdefault(action, []).append(frame)
        body_atlas.save(output_dir / f"tide-{action}.png")
        compiled_files.append(body_name)
        # Keep a corresponding canonical coat atlas even when some records omit overrides;
        # omitted per-cel overrides remain absent and runtime coverage validation diagnoses them.
        coat_atlas.save(output_dir / f"coat-{action}.png")
        compiled_files.append(coat_name)
    return poses, compiled_files


def _compile_parts(data: dict[str, Any], pack: Path, output_dir: Path) -> tuple[dict[str, Any], list[str]]:
    authored = data.get("parts")
    if not isinstance(authored, dict):
        raise ValueError("authoring.json requires parts.hair and parts.hats")
    result: dict[str, Any] = {"hair": {}, "hats": {}}
    compiled_files: list[str] = []
    cell_size = _part_canvas(data.get("part_canvas"))
    cell_anchor = (cell_size[0] // 2, cell_size[1] // 2)
    for kind in ("hair", "hats"):
        styles = authored.get(kind, {})
        if not isinstance(styles, dict) or not styles:
            raise ValueError(f"parts.{kind} must contain authored styles")
        for style, views in styles.items():
            if not isinstance(views, dict):
                raise ValueError(f"parts.{kind}.{style} must contain eight direction records")
            missing = set(DIRECTIONS) - set(views)
            if missing:
                raise ValueError(f"parts.{kind}.{style} is missing directions: " + ", ".join(sorted(missing)))
            output_name = f"compiled/{kind}-{style}.png"
            underhat_name = f"compiled/{kind}-{style}-underhat.png"
            atlas = Image.new("RGBA", (cell_size[0] * len(DIRECTIONS), cell_size[1]))
            underhat_atlas = Image.new("RGBA", atlas.size)
            has_hat_variants = kind == "hair" and any(isinstance(views[direction], dict) and "hat_variant" in views[direction] for direction in DIRECTIONS)
            if has_hat_variants and any(not isinstance(views[direction], dict) or "hat_variant" not in views[direction] for direction in DIRECTIONS):
                raise ValueError(f"parts.hair.{style} hat_variant coverage must include all eight directions")
            has_underhat = kind == "hair" and (has_hat_variants or any(isinstance(views[direction], dict) and "hat_clip_y" in views[direction] for direction in DIRECTIONS))
            result[kind][style] = {}
            for col, direction in enumerate(DIRECTIONS):
                record = views[direction]
                if not isinstance(record, dict):
                    raise ValueError(f"parts.{kind}.{style}/{direction} must be an object")
                context = f"parts.{kind}.{style}/{direction}"
                cell = _compile_part_record(record, pack, cell_size, context)
                atlas.alpha_composite(cell, (col * cell_size[0], 0))
                order = record.get("order", "front")
                if order not in {"behind", "front"}:
                    raise ValueError(f"parts.{kind}.{style}/{direction} order must be behind or front")
                layer = {
                    "source": output_name,
                    "region": [col * cell_size[0], 0, cell_size[0], cell_size[1]],
                    "anchor": list(cell_anchor),
                    "offset": [round(value) for value in _number_pair(record.get("offset", [0, 0]), "part offset")],
                    "order": order,
                }
                entry: dict[str, Any] = {"layers": [layer], "source_record": _copy_record(record)}
                clear_regions = _validate_hat_clear_regions(record.get("hat_clear_regions", []), context, cell_size)
                if clear_regions and "hat_clip_y" not in record:
                    raise ValueError(f"parts.{kind}.{style}/{direction} hat_clear_regions require hat_clip_y")
                if has_underhat and "hat_variant" in record:
                    variant = record["hat_variant"]
                    variant_cell = _compile_part_record(variant, pack, cell_size, f"{context}/hat_variant", preserve_components=True)
                    underhat_atlas.alpha_composite(variant_cell, (col * cell_size[0], 0))
                    underhat_layer = dict(layer)
                    underhat_layer["source"] = underhat_name
                    underhat_layer["order"] = "front"
                    entry["hat_layers"] = [underhat_layer]
                    entry["hat_layers_include_hat"] = True
                elif has_underhat and "hat_clip_y" in record:
                    clipped = clip_hat_part(cell, record["hat_clip_y"])
                    underhat_atlas.alpha_composite(clear_hat_regions(clipped, clear_regions), (col * cell_size[0], 0))
                    underhat_layer = dict(layer)
                    underhat_layer["source"] = underhat_name
                    underhat_layer["order"] = "front"
                    entry["hat_layers"] = [underhat_layer]
                result[kind][style][direction] = entry
            atlas.save(output_dir / f"{kind}-{style}.png")
            compiled_files.append(output_name)
            if has_underhat:
                underhat_atlas.save(output_dir / f"{kind}-{style}-underhat.png")
                compiled_files.append(underhat_name)
    if "traveller" not in result["hats"]:
        raise ValueError("parts.hats.traveller is required by the runtime appearance contract")
    if not {"windswept", "bob"}.issubset(result["hair"]):
        raise ValueError("parts.hair must include windswept and bob styles")
    return result, compiled_files


def _read_manifest_region(pack: Path, frame: dict[str, Any]) -> Image.Image:
    source = Image.open(_pack_path(pack, frame["source"])).convert("RGBA")
    x, y, width, height = frame["region"]
    return source.crop((x, y, x + width, y + height))


def _compose_layers(canvas: Image.Image, layers: list[dict[str, Any]], head: list[int], pack: Path, order: str) -> None:
    for layer in layers:
        if layer.get("order") != order:
            continue
        part = _read_manifest_region(pack, layer)
        anchor = layer["anchor"]
        offset = layer.get("offset", [0, 0])
        canvas.alpha_composite(part, (head[0] - anchor[0] + offset[0], head[1] - anchor[1] + offset[1]))


def _compile_fallback(pack: Path, poses: dict[str, Any], parts: dict[str, Any], output_dir: Path) -> dict[str, Any]:
    frame = poses["front"].get("idle", poses["front"].get("walk", []))[0]
    body = _read_manifest_region(pack, frame)
    canvas = Image.new("RGBA", CANVAS)
    hair_entry = parts["hair"]["windswept"]["front"]
    head = frame["head_anchor"]
    _compose_layers(canvas, hair_entry["layers"], head, pack, "behind")
    canvas.alpha_composite(body)
    _compose_layers(canvas, hair_entry["layers"], head, pack, "front")
    canvas.save(output_dir / "fallback.png")
    return {"source": "compiled/fallback.png", "region": [0, 0, CANVAS[0], CANVAS[1]], "head_anchor": list(head), "feet": list(FEET)}


def _compose_gallery_cell(pack: Path, poses: dict[str, Any], parts: dict[str, Any], direction: str, frame_index: int, hair: str, hat_on: bool, outfit: str) -> Image.Image:
    frame = poses[direction]["idle"][0]
    selected = frame
    if outfit == "long_coat" and "long_coat" in frame.get("outfits", {}):
        selected = frame["outfits"]["long_coat"]
    body = _read_manifest_region(pack, selected)
    result = Image.new("RGBA", CANVAS)
    head = selected["head_anchor"]
    hair_entry = parts["hair"][hair][direction]
    hair_layers = hair_entry.get("hat_layers", hair_entry["layers"]) if hat_on else hair_entry["layers"]
    hat_layers = parts["hats"]["traveller"][direction]["layers"] if hat_on and not hair_entry.get("hat_layers_include_hat", False) else []
    _compose_layers(result, hair_layers, head, pack, "behind")
    _compose_layers(result, hat_layers, head, pack, "behind")
    result.alpha_composite(body)
    _compose_layers(result, hair_layers, head, pack, "front")
    _compose_layers(result, hat_layers, head, pack, "front")
    return result


def _write_preview_v2(pack: Path, poses: dict[str, Any], parts: dict[str, Any]) -> Path:
    combos = [(hair, hat_on, outfit) for hair in ("windswept", "bob") for hat_on in (False, True) for outfit in ("tide_jacket", "long_coat")]
    board = Image.new("RGBA", (CANVAS[0] * len(DIRECTIONS), CANVAS[1] * len(combos)), (39, 53, 61, 255))
    for row, (hair, hat_on, outfit) in enumerate(combos):
        for col, direction in enumerate(DIRECTIONS):
            image = _compose_gallery_cell(pack, poses, parts, direction, 0, hair, hat_on, outfit)
            board.alpha_composite(image, (col * CANVAS[0], row * CANVAS[1]))
    path = pack / "binding-preview-v2.png"
    board.save(path)
    return path


def compile_pack(pack: Path = PACK, *, write_manifest: bool = True, write_preview: bool = True) -> dict[str, Any]:
    """Compile complete authored action cels, parts, fallback, and runtime manifest."""
    pack = Path(pack).resolve()
    authoring_path = pack / "authoring.json"
    try:
        data = json.loads(authoring_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read valid authoring.json: {error}") from error
    if not isinstance(data, dict) or int(data.get("schema_version", 0)) != 1:
        raise ValueError("authoring.json schema_version must be 1")
    output_dir = pack / "compiled"
    output_dir.mkdir(parents=True, exist_ok=True)
    poses, compiled_files = _compile_poses(data, pack, output_dir)
    parts, part_files = _compile_parts(data, pack, output_dir)
    compiled_files.extend(part_files)
    fallback = _compile_fallback(pack, poses, parts, output_dir)
    compiled_files.append("compiled/fallback.png")
    if write_preview:
        _write_preview_v2(pack, poses, parts)
    files = sorted(set(compiled_files))
    manifest = {
        "production": "2d-authored-layers",
        "format": "production2d-authored-layers",
        "schema_version": 1,
        "canvas": list(CANVAS),
        "feet_origin": list(FEET),
        "part_canvas": list(_part_canvas(data.get("part_canvas"))),
        "directions": list(DIRECTIONS),
        "outfits": {"tide_jacket": {}, "long_coat": {}},
        "default_outfit": "tide_jacket",
        "default_hair": "windswept",
        "poses": poses,
        "hair": parts["hair"],
        "hats": parts["hats"],
        "fallback": fallback,
        "files": files,
        "character_model_files": [],
    }
    if write_manifest:
        (pack / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    registration = {"poses": poses, "parts": parts, "fallback": fallback, "files": files}
    (output_dir / "registration.json").write_text(json.dumps(registration, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    manifest = compile_pack(PACK)
    actions = sorted(manifest["poses"]["front"])
    print(f"Compiled 2D authored actions {', '.join(actions)}, eight directions, hair/hat layers, and complete fallback")


if __name__ == "__main__":
    main()
