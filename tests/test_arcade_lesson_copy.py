"""Arcade lessons stay short enough to fit the smallest supported window.

Arcade games teach by playing; the optional lesson is a reminder, so each field
keeps to one short sentence. Longer copy overflowed the 800x450 tutorial page.
"""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ("goal", "input", "success")
# Measured: fields up to 46 characters fit the 800x450 tutorial page.
MAX_CHARS = 46


def arcade_ids() -> set[str]:
    ids = set()
    for path in sorted((ROOT / "game" / "data").glob("*_games.json")):
        for row in json.loads(path.read_text(encoding="utf-8")):
            if row.get("arcade"):
                ids.add(row["id"])
    return ids


def lessons() -> dict:
    data = json.loads((ROOT / "game" / "data" / "tutorials.json").read_text(encoding="utf-8"))
    rows = data.get("lessons", data) if isinstance(data, dict) else data
    return rows if isinstance(rows, dict) else {row.get("id"): row for row in rows}


class ArcadeLessonCopyTest(unittest.TestCase):
    def test_arcade_lesson_fields_are_short(self):
        ids = arcade_ids()
        self.assertTrue(ids, "expected at least one arcade game")
        too_long = []
        for lesson_id, lesson in lessons().items():
            if lesson_id not in ids:
                continue
            for index, step in enumerate(lesson.get("steps", [])):
                for field in FIELDS:
                    text = step.get(field, "")
                    if len(text) > MAX_CHARS:
                        too_long.append(f"{lesson_id} step {index} {field}: {len(text)} chars")
        self.assertEqual(too_long, [], "arcade lesson copy must stay within one short sentence")


if __name__ == "__main__":
    unittest.main()
