import hashlib
import json
import unittest
from pathlib import Path, PurePosixPath


REPO_ROOT = Path(__file__).resolve().parents[1]
FONT_ROOT = REPO_ROOT / "assets" / "fonts"
PROVENANCE_PATH = FONT_ROOT / "font-provenance.json"
EXPECTED_FUSION_FILES = {
    "assets/fonts/pixel/fusion-pixel-12px-proportional-zh_tw.otf",
    "assets/fonts/pixel/fusion-pixel-12px-proportional-latin.otf",
    "assets/fonts/pixel/fusion-pixel-12px-proportional-ja.otf",
    "assets/fonts/pixel/fusion-pixel-12px-proportional-ko.otf",
}
EXPECTED_FUSION_SUBLICENSES = {
    "assets/fonts/pixel/LICENSES/ark-pixel/OFL.txt": "Ark Pixel Font",
    "assets/fonts/pixel/LICENSES/cubic-11/OFL.txt": "Cubic 11",
    "assets/fonts/pixel/LICENSES/galmuri/LICENSE.txt": "Lee Minseo",
}


def load_provenance():
    with PROVENANCE_PATH.open("r", encoding="utf-8") as source:
        return json.load(source)


def repo_file(relative_path):
    path = PurePosixPath(relative_path)
    if path.is_absolute() or ".." in path.parts or "\\" in relative_path:
        raise AssertionError(f"Path must be repository-relative POSIX form: {relative_path!r}")
    resolved = (REPO_ROOT / Path(*path.parts)).resolve()
    if not resolved.is_relative_to(REPO_ROOT.resolve()):
        raise AssertionError(f"Path resolves outside the repository: {relative_path!r}")
    return resolved


class FontProvenanceTests(unittest.TestCase):
    def test_manifest_schema_and_pinned_fusion_archive(self):
        manifest = load_provenance()
        self.assertEqual(manifest.get("schema"), 1)
        self.assertRegex(manifest.get("checked_on", ""), r"^\d{4}-\d{2}-\d{2}$")
        self.assertEqual(
            manifest.get("upstream"),
            "https://github.com/TakWolf/fusion-pixel-font",
        )
        release = manifest.get("pixel_release", {})
        self.assertEqual(release.get("tag"), "2026.09.25")
        self.assertEqual(
            release.get("asset"),
            "fusion-pixel-font-12px-proportional-otf-v2026.09.25.zip",
        )
        self.assertEqual(
            release.get("download"),
            "https://github.com/TakWolf/fusion-pixel-font/releases/download/"
            "2026.09.25/fusion-pixel-font-12px-proportional-otf-v2026.09.25.zip",
        )
        self.assertRegex(release.get("sha256", ""), r"^[0-9a-f]{64}$")
        for key in ("license_note", "fallback", "source_character_coverage"):
            self.assertIn(key, manifest)
        coverage = manifest["source_character_coverage"]
        self.assertTrue({"scope", "unique_characters", "primary_missing", "primary_plus_cjk_missing", "note"}.issubset(coverage))
        self.assertGreater(coverage["unique_characters"], 0)

    def test_records_cover_every_bundled_font_and_match_bytes(self):
        manifest = load_provenance()
        records = manifest.get("files")
        self.assertIsInstance(records, list)
        actual_fonts = {
            path.relative_to(REPO_ROOT).as_posix()
            for path in FONT_ROOT.rglob("*")
            if path.is_file() and path.suffix.lower() in {".otf", ".ttf"}
        }
        recorded_paths = [record.get("path") for record in records]
        self.assertEqual(len(recorded_paths), len(set(recorded_paths)), "Each font needs one provenance record.")
        self.assertEqual(set(recorded_paths), actual_fonts, "The manifest must cover exactly the bundled TTF/OTF files.")

        required_fields = {"path", "sha256", "bytes", "language_variant", "license", "license_path"}
        for record in records:
            with self.subTest(font=record.get("path")):
                self.assertTrue(required_fields.issubset(record))
                font_path = repo_file(record["path"])
                self.assertTrue(font_path.is_file())
                payload = font_path.read_bytes()
                self.assertEqual(record["bytes"], len(payload))
                self.assertRegex(record["sha256"], r"^[0-9a-f]{64}$")
                self.assertEqual(record["sha256"], hashlib.sha256(payload).hexdigest())
                self.assertTrue(record["language_variant"])
                self.assertTrue(record["license"])
                license_path = repo_file(record["license_path"])
                self.assertTrue(license_path.is_file())
                self.assertGreater(license_path.stat().st_size, 0)
                license_text = license_path.read_text(encoding="utf-8", errors="replace")
                self.assertRegex(license_text, r"(?i)SIL OPEN FONT LICENSE|free software")

        fusion_records = [record for record in records if record["path"] in EXPECTED_FUSION_FILES]
        self.assertEqual({record["path"] for record in fusion_records}, EXPECTED_FUSION_FILES)
        self.assertEqual({record["license_path"] for record in fusion_records}, {"assets/fonts/pixel/OFL.txt"})
        self.assertTrue(all(record["license"] == "OFL-1.1" for record in fusion_records))
        self.assertTrue(all(record.get("glyph_count") == 36999 for record in fusion_records))

    def test_fusion_12px_distribution_includes_all_sublicenses(self):
        license_root = FONT_ROOT / "pixel" / "LICENSES"
        actual_sublicenses = {
            path.relative_to(REPO_ROOT).as_posix()
            for path in license_root.rglob("*")
            if path.is_file()
        }
        self.assertEqual(actual_sublicenses, set(EXPECTED_FUSION_SUBLICENSES))
        for relative_path, identifying_text in EXPECTED_FUSION_SUBLICENSES.items():
            with self.subTest(license=relative_path):
                license_path = repo_file(relative_path)
                self.assertTrue(license_path.is_file())
                text = license_path.read_text(encoding="utf-8", errors="replace")
                self.assertIn(identifying_text, text)
                self.assertGreater(len(text.strip()), 1000, "Keep the full upstream sublicense text.")


if __name__ == "__main__":
    unittest.main()
