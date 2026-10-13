"""Integrity and licensing coverage for the shipped audio assets.

This deliberately does not attempt to judge whether an asset sounds good;
listening remains a separate, pending acceptance step.
"""

from __future__ import annotations

import array
import hashlib
import json
import math
import re
import struct
import unittest
import wave
from pathlib import Path, PurePosixPath
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "assets/audio/cc0/catalog.json"
AUDIO_DIRECTOR_PATH = ROOT / "game/audio/audio_director.gd"
CC0_URL = "https://creativecommons.org/publicdomain/zero/1.0/"
EXPECTED_COUNTS = {"music": 3, "effect": 5, "ambience": 1, "note": 4}
EXPECTED_TOTAL = sum(EXPECTED_COUNTS.values())
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _https_url(value: object) -> bool:
    if not isinstance(value, str):
        return False
    parsed = urlparse(value)
    return parsed.scheme == "https" and bool(parsed.netloc)


class AudioLicenseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
        cls.audio_director = AUDIO_DIRECTOR_PATH.read_text(encoding="utf-8")
        cls.assets = cls.catalog["assets"]
        cls.sources = {source["id"]: source for source in cls.catalog["sources"]}
        cls.assets_by_path: dict[str, list[dict]] = {}
        for asset in cls.assets:
            cls.assets_by_path.setdefault(asset["path"], []).append(asset)

    def _routed_paths(self) -> dict[str, set[str]]:
        """Parse the literal route dictionaries and ambience constant."""
        routed: dict[str, set[str]] = {}
        for constant, kind in (("MUSIC_PATHS", "music"), ("SFX_PATHS", "effect")):
            match = re.search(
                rf"const\s+{constant}\s*:=\s*\{{(.*?)\n\}}",
                self.audio_director,
                re.DOTALL,
            )
            self.assertIsNotNone(match, f"could not locate {constant} dictionary")
            paths = {
                path
                for path in re.findall(r'"res://(assets/audio/[^"\n]+)"', match.group(1))
            }
            routed[kind] = paths

        ambience = re.search(
            r'const\s+AMBIENCE_PATH\s*:=\s*"res://(assets/audio/[^"\n]+)"',
            self.audio_director,
        )
        self.assertIsNotNone(ambience, "could not locate AMBIENCE_PATH")
        routed["ambience"] = {ambience.group(1)}

        # Keep the production loop's formatted filename visible to this audit.
        self.assertRegex(
            self.audio_director,
            r'"res://assets/audio/note_%d\.wav"\s*%\s*index',
            "note path pattern changed; update this coverage check",
        )
        routed["note"] = {f"assets/audio/note_{index}.wav" for index in range(4)}
        return routed

    def test_every_routed_audio_path_has_exactly_one_manifest_asset(self) -> None:
        routed = self._routed_paths()
        self.assertEqual(EXPECTED_COUNTS, {kind: len(paths) for kind, paths in routed.items()})
        self.assertEqual(EXPECTED_TOTAL, sum(map(len, routed.values())))

        routed_paths = set().union(*routed.values())
        manifest_paths = set(self.assets_by_path)
        self.assertEqual(routed_paths, manifest_paths)
        for kind, paths in routed.items():
            for path in paths:
                entries = self.assets_by_path.get(path, [])
                self.assertEqual(1, len(entries), f"{path} must have exactly one manifest record")
                self.assertEqual(kind, entries[0]["kind"], f"wrong kind for {path}")

    def test_manifest_files_stay_inside_repository_and_match_digest_and_size(self) -> None:
        for asset in self.assets:
            with self.subTest(asset=asset["path"]):
                relative = PurePosixPath(asset["path"])
                self.assertFalse(relative.is_absolute(), "manifest paths must be relative")
                self.assertNotIn("..", relative.parts, "manifest path may not traverse upward")
                path = (ROOT / Path(*relative.parts)).resolve()
                self.assertTrue(path.is_relative_to(ROOT.resolve()), "resolved asset escapes repository")
                self.assertTrue(path.is_file(), f"missing audio file: {asset['path']}")
                data = path.read_bytes()
                self.assertGreater(len(data), 0, "audio file is empty")
                self.assertEqual(asset["bytes"], len(data), "manifest byte count differs")
                self.assertRegex(asset["sha256"], SHA256_RE)
                self.assertEqual(asset["sha256"], hashlib.sha256(data).hexdigest())

    def test_sources_have_cc0_and_verifiable_origin_records(self) -> None:
        self.assertEqual(len(self.sources), len(self.catalog["sources"]), "source IDs must be unique")
        for source_id, source in self.sources.items():
            with self.subTest(source=source_id):
                self.assertEqual("CC0-1.0", source.get("license"))
                self.assertEqual(CC0_URL, source.get("license_url"))
                included_license = source.get("included_license")
                if included_license:
                    license_path = (ROOT / included_license).resolve()
                    self.assertTrue(license_path.is_relative_to(ROOT.resolve()))
                    self.assertTrue(license_path.is_file(), "included license file must exist")
                    license_text = license_path.read_text(encoding="utf-8")
                    self.assertTrue(license_text.strip(), "included license file must not be empty")
                    self.assertIn("CC0", license_text)
                if source_id == "snapland-generated":
                    self.assertTrue(included_license, "original audio needs an explicit license file")
                    license_path = (ROOT / included_license).resolve()
                    license_text = license_path.read_text(encoding="utf-8")
                    self.assertIn("CC0 1.0 Universal", license_text)
                    self.assertIn(CC0_URL, license_text)
                else:
                    self.assertTrue(_https_url(source.get("page_url")), "source page must use HTTPS")
                    self.assertTrue(_https_url(source.get("download_url")), "download origin must use HTTPS")
                    self.assertRegex(source.get("page_sha256", ""), SHA256_RE)
                    evidence = source.get("evidence", "")
                    evidence_path = (ROOT / evidence).resolve()
                    self.assertTrue(evidence_path.is_relative_to(ROOT.resolve()))
                    self.assertTrue(evidence_path.is_file(), f"missing source-page screenshot: {evidence}")
                    records = [asset for asset in self.assets if asset.get("source_id") == source_id]
                    self.assertTrue(records, "third-party source must be used by a manifest asset")
                    for asset in records:
                        self.assertRegex(asset.get("source_sha256", ""), SHA256_RE)
                        self.assertTrue(asset.get("source_file"), "original source filename is required")
        for asset in self.assets:
            self.assertIn(
                asset.get("source_id"), self.sources,
                f"asset {asset['path']} references an unknown source",
            )

    def test_audio_container_headers_and_catalog_measurements(self) -> None:
        for asset in self.assets:
            path = ROOT / Path(*PurePosixPath(asset["path"]).parts)
            data = path.read_bytes()
            with self.subTest(asset=asset["path"]):
                if path.suffix.lower() == ".wav":
                    with wave.open(str(path), "rb") as wav:
                        self.assertEqual("NONE", wav.getcomptype(), "WAV must be uncompressed PCM")
                        self.assertIn(wav.getnchannels(), (1, 2))
                        self.assertIn(wav.getframerate(), (22050, 44100))
                        self.assertEqual(2, wav.getsampwidth(), "WAV must use PCM16")
                        frame_count = wav.getnframes()
                        self.assertGreater(frame_count, 0)
                        frames = wav.readframes(frame_count)
                    self.assertEqual(frame_count * wav.getnchannels() * 2, len(frames))
                    samples = array.array("h")
                    samples.frombytes(frames)
                    if struct.pack("=H", 1) != struct.pack("<H", 1):
                        samples.byteswap()
                    peak = max(abs(sample) for sample in samples)
                    self.assertGreater(peak, 0, "WAV must contain a non-silent signal")
                    self.assertLess(peak, 32767, "WAV sample is saturated")
                    self.assertLessEqual(peak / 32768.0, 0.95, "WAV peak exceeds safe headroom")
                elif path.suffix.lower() == ".ogg":
                    self.assertGreater(len(data), 64)
                    self.assertTrue(data.startswith(b"OggS"), "OGG page header is missing")
                    self.assertIn(b"\x01vorbis", data[:256], "Vorbis identification header is missing")
                    measurement = asset.get("measurement", {})
                    input_tp = float(measurement["input_tp"])
                    input_i = float(measurement["input_i"])
                    self.assertTrue(math.isfinite(input_tp))
                    self.assertLess(input_tp, -5.0, "catalog input true peak must be below -5 dB")
                    self.assertTrue(math.isfinite(input_i), "catalog input integrated loudness must be finite")
                else:
                    self.fail(f"unsupported shipped audio format: {path.suffix}")

    def test_audio_review_remains_pending_listening(self) -> None:
        self.assertTrue(self.assets)
        status = self.catalog.get("status")
        if status == "technical-integration-pending-audition":
            self.assertTrue(
                all(asset.get("audition") == "pending_local_listening" for asset in self.assets),
                "pending catalog status requires every asset to remain pending",
            )
            return

        self.assertEqual("accepted", status, "unknown catalog audition status")
        for asset in self.assets:
            with self.subTest(asset=asset["path"]):
                self.assertEqual("accepted", asset.get("audition"))
                evidence = asset.get("listening_evidence")
                self.assertIsInstance(evidence, str)
                self.assertTrue(evidence.strip())
                evidence_path = (ROOT / evidence).resolve()
                self.assertTrue(evidence_path.is_relative_to(ROOT.resolve()))
                self.assertTrue(evidence_path.is_file(), "listening evidence file must exist")
                self.assertTrue(
                    isinstance(asset.get("human_reviewer"), str)
                    and asset["human_reviewer"].strip(),
                    "accepted assets require a named human reviewer",
                )
                self.assertTrue(
                    isinstance(asset.get("reviewed_on"), str) and asset["reviewed_on"].strip(),
                    "accepted assets require a review date",
                )


if __name__ == "__main__":
    unittest.main()
