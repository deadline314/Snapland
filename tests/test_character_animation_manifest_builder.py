import importlib.util
import copy
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("animation_manifest_builder", ROOT / "tools/build_character_animation_manifest.py")
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class CharacterAnimationManifestBuilderTests(unittest.TestCase):
    def test_turn_endpoints_share_the_exact_existing_neutral_pose(self):
        before = json.loads(BUILDER.OUT.read_text(encoding="utf-8"))
        after, _ = BUILDER.build()
        for role in ("ticket", "imp", "announcer"):
            for direction in ("right", "left"):
                frames = after["actors"][role]["settle"][direction]["frames"]
                self.assertEqual(after["actors"][role]["idle"]["front"]["frames"][0], frames[-1])
                self.assertEqual(before["actors"][role]["settle"][direction]["frames"][:3], frames[:3])

    def test_departures_reuse_complete_turn_sources_without_changing_other_actions(self):
        after, _ = BUILDER.build()
        for role in ("ticket", "imp", "announcer"):
            for direction in ("right", "left"):
                departure = after["actors"][role].get("depart", {}).get(direction, {})
                self.assertEqual(4, len(departure.get("frames", [])))
                self.assertFalse(departure["loop"])
                self.assertNotIn("return_direction", departure)
                self.assertEqual(list(reversed(after["actors"][role]["settle"][direction]["frames"])), departure["frames"])

    def test_announcer_turn_has_complete_finite_sources(self):
        after, reports = BUILDER.build()
        for direction in ("right", "left"):
            sequence = after["actors"]["announcer"].get("settle", {}).get(direction, {})
            self.assertEqual(4, len(sequence.get("frames", [])))
            self.assertFalse(sequence["loop"])
            self.assertEqual("front", sequence["return_direction"])
            self.assertEqual(10, sequence["fps"])
        self.assertEqual(8, reports["announcer"]["settle_side_atlas"]["frame_count"])

    def test_ticket_turn_is_finite_and_keeps_existing_sources_and_wardrobe(self):
        before = json.loads(BUILDER.OUT.read_text(encoding="utf-8"))
        after, reports = BUILDER.build()
        for direction in ("right", "left"):
            sequence = after["actors"]["ticket"].get("settle", {}).get(direction, {})
            self.assertEqual(4, len(sequence.get("frames", [])))
            self.assertFalse(sequence["loop"])
            self.assertEqual("front", sequence["return_direction"])
            self.assertEqual(10, sequence["fps"])
        self.assertEqual(8, reports["ticket"]["settle_side_atlas"]["frame_count"])
        for actor, actions in before["actors"].items():
            for action, value in actions.items():
                if actor in ("ticket", "imp", "announcer") and action == "settle":
                    continue
                if actor in ("ticket", "imp", "announcer") and action == "depart":
                    continue
                self.assertEqual(value, after["actors"][actor][action], (actor, action))
        for key in ("outfit_modes", "outfit_required_poses"):
            self.assertEqual(before[key], after[key])

    def test_stale_or_invalid_authoring_input_cannot_overwrite_manifest(self):
        approved = json.loads(BUILDER.AUTHORING.read_text(encoding="utf-8"))
        damaged_inputs = []
        for kind in ("source", "geometry", "canonical_canvas", "field", "coordinates", "duplicate", "wardrobe"):
            damaged = copy.deepcopy(approved)
            clip = damaged["frame_annotations"][0]
            if kind == "source":
                clip["source_sha256"] = "0" * 64
            elif kind == "geometry":
                clip["frames"][0]["region"][0] += 1
            elif kind == "canonical_canvas":
                clip["feet_baseline"] += 1
            elif kind == "field":
                clip["frames"][0]["metadata"]["source"] = "res://unreviewed.png"
            elif kind == "coordinates":
                clip["frames"][0]["metadata"]["normalized_face_eyes"][0][0] = -1
            elif kind == "duplicate":
                clip["frames"].append(copy.deepcopy(clip["frames"][0]))
            else:
                damaged["outfit_modes"]["outfit-coral"] = "unknown"
            damaged_inputs.append((kind, damaged))
        original = BUILDER.OUT.read_bytes()
        with tempfile.TemporaryDirectory() as temporary:
            manifest = Path(temporary) / "regions.json"
            authoring = Path(temporary) / "authoring.json"
            manifest.write_bytes(original)
            for kind, damaged in damaged_inputs:
                with self.subTest(kind=kind):
                    authoring.write_text(json.dumps(damaged), encoding="utf-8")
                    with patch.object(BUILDER, "OUT", manifest), patch.object(BUILDER, "AUTHORING", authoring), patch("sys.argv", ["builder", "--write"]), contextlib.redirect_stderr(io.StringIO()) as errors:
                        self.assertEqual(1, BUILDER.main())
                    self.assertIn("animation authoring", errors.getvalue())
                    self.assertEqual(original, manifest.read_bytes())

    def test_missing_authoring_input_stops_build(self):
        with tempfile.TemporaryDirectory() as temporary:
            with patch.object(BUILDER, "AUTHORING", Path(temporary) / "missing.json"):
                with self.assertRaises(FileNotFoundError):
                    BUILDER.build()

    def test_full_build_preserves_reviewed_wardrobe_and_pose_annotations(self):
        before = json.loads(BUILDER.OUT.read_text(encoding="utf-8"))
        after, _ = BUILDER.build()
        for key in ("outfit_modes", "outfit_required_poses"):
            self.assertEqual(before[key], after.get(key), key)
        self.assertEqual(before["coverage_notes"]["traveller_outfit_coral"], after["coverage_notes"]["traveller_outfit_coral"])
        for index, frame in enumerate(before["actors"]["traveller"]["photograph"]["front"]["frames"]):
            actual = after["actors"]["traveller"]["photograph"]["front"]["frames"][index]
            for key in ("normalized_face_eyes", "normalized_head_contour", "foreground_polygons"):
                if key in frame:
                    self.assertEqual(frame[key], actual.get(key), (index, key))

    def test_full_build_preserves_separately_authored_actions_and_directions(self):
        before = json.loads(BUILDER.OUT.read_text(encoding="utf-8"))
        before["actors"]["traveller"]["wave"]["left"] = {"fps": 2, "frames": [{"source": "separate-authoring-fixture"}]}
        with tempfile.TemporaryDirectory() as temporary:
            manifest = Path(temporary) / "regions.json"
            manifest.write_text(json.dumps(before), encoding="utf-8")
            with patch.object(BUILDER, "OUT", manifest):
                after, _ = BUILDER.build()
        for action in ("sit", "catch"):
            self.assertEqual(before["actors"]["traveller"][action], after["actors"]["traveller"].get(action))
        self.assertEqual(before["actors"]["traveller"]["wave"]["left"], after["actors"]["traveller"]["wave"].get("left"))
        self.assertEqual(4, len(after["actors"]["traveller"]["idle"]["front_left"]["frames"]))


if __name__ == "__main__":
    unittest.main()
