from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from tools.island_avatar import staging
from tools.walk_stability import run_audit


class AuditResourceStagingTests(unittest.TestCase):
    def fixture(self, root):
        files = {
            'game/entry.gd': b'''extends SceneTree\nvar guide = "res://assets/layers.json"\nvar icon = 'res://assets/icon.png'\n''',
            'assets/layers.json': b'''{"layer":"res://assets/coat.pngdata","script":"res://game/owner.gd","unsupported":"res://assets/archive.pngdata.backup"}''',
            'game/owner.gd': b'extends RefCounted\n',
            'assets/coat.pngdata': b'\x89PNG\r\n\x1a\nraw garment bytes',
            'assets/icon.png': b'original icon bytes',
            'assets/characters/hero-2d-v1/manifest.json': b'{}',
        }
        for name, data in files.items():
            target = root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        return files

    def assert_graph(self, stage, files, extra=()):
        expected = set(files) - {'assets/characters/hero-2d-v1/manifest.json'}
        expected.update(extra)
        actual = {str(p.relative_to(stage)) for p in stage.rglob('*') if p.is_file()}
        self.assertEqual(actual, expected | {'project.godot'})
        for name in expected:
            self.assertEqual((stage / name).read_bytes(), files[name])
        self.assertFalse((stage / 'assets/coat.png').exists())

    def test_island_audit_keeps_raw_png_data_extension_and_dependency_graph(self):
        with tempfile.TemporaryDirectory(prefix='snapland-island-refs-') as directory:
            root = Path(directory)
            files = self.fixture(root)
            with patch.object(staging, 'ROOT', root):
                project = staging.prepare('island-avatar-raw-data', ['game/entry.gd'])
            self.assert_graph(project, files)

    def test_walk_audit_keeps_raw_png_data_extension_and_dependency_graph(self):
        with tempfile.TemporaryDirectory(prefix='snapland-walk-refs-') as directory:
            root = Path(directory)
            files = self.fixture(root)
            project = root / 'build/walk-stability-audit'
            with patch.multiple(run_audit, ROOT=root, PROJECT=project, SOURCES=['game/entry.gd']), patch.object(run_audit, '_listed_pack_files', return_value=[]):
                run_audit.prepare()
            self.assert_graph(project, files, ['assets/characters/hero-2d-v1/manifest.json'])
