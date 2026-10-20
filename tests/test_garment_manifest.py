import copy
import json
import unittest
from tools.island_avatar.garment_manifest import DEFAULT_GUIDE, IDLE_GUIDE, ROOT, validate, validate_collection

class GarmentManifestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.guide = json.loads(DEFAULT_GUIDE.read_text())
        cls.required = json.loads((ROOT / 'assets/characters/complete-animation-regions.json').read_text())['outfit_required_poses']['traveller']

    def check_invalid(self, mutate, text):
        guide = copy.deepcopy(self.guide)
        mutate(guide)
        with self.assertRaisesRegex(ValueError, text):
            validate(guide, self.required)

    def test_partial_front_preview_identifies_all_other_required_cels(self):
        report = validate(self.guide, self.required)
        self.assertEqual((report['required'], report['provided'], report['missing_count']), (148, 8, 140))
        self.assertFalse(report['authored_coverage_complete'])
        self.assertEqual(report['runtime_fallback_request_count'], 24)
        self.assertFalse(report['runtime_fallbacks_are_authored_art'])
        self.assertEqual({row['action'] for row in report['runtime_fallback_requests']}, {'celebrate'})
        self.assertEqual(len({row['direction'] for row in report['runtime_fallback_requests']}), 8)
        self.assertFalse(report['coverage_complete'])
        self.assertFalse(report['ready_for_wardrobe'])
        self.assertIn({'action': 'catch', 'direction': 'front', 'frame': 11}, report['missing'])
        self.assertIn({'action': 'walk', 'direction': 'back', 'frame': 7}, report['missing'])
        self.assertNotIn({'action': 'walk', 'direction': 'front', 'frame': 7}, report['missing'])

    def test_two_validated_atlases_report_exact_union_without_enabling_the_outfit(self):
        idle = json.loads(IDLE_GUIDE.read_text())
        report = validate_collection([self.guide, idle], self.required)
        self.assertEqual((report['required'], report['provided'], report['missing_count']), (148, 44, 104))
        self.assertEqual(report['source_guides'], 2)
        self.assertEqual(report['runtime_fallback_request_count'], 24)
        self.assertFalse(report['ready_for_wardrobe'])
        self.assertIn({'action': 'walk', 'direction': 'back', 'frame': 7}, report['missing'])
        self.assertNotIn({'action': 'idle', 'direction': 'back', 'frame': 3}, report['missing'])

    def test_source_atlases_cannot_double_count_or_combine_different_garments(self):
        with self.assertRaisesRegex(ValueError, 'duplicate cel across'):
            validate_collection([self.guide, self.guide], self.required)
        other = json.loads(IDLE_GUIDE.read_text())
        other['outfit'] = 'another-garment'
        with self.assertRaisesRegex(ValueError, 'different garments'):
            validate_collection([self.guide, other], self.required)
        with self.assertRaisesRegex(ValueError, 'at least one'):
            validate_collection([], self.required)

    def test_outfit_identity_cannot_be_empty_or_a_container(self):
        for value in ['', [], '../outside', 'contains spaces']:
            self.check_invalid(lambda g: g.update(outfit=value), 'stable nonempty identifier')

    def test_duplicate_preview_cannot_count_as_additional_coverage(self):
        self.check_invalid(lambda g: g['frames'].append(copy.deepcopy(g['frames'][0])), 'duplicate cel')

    def test_renaming_frame_cannot_hide_a_missing_required_pose(self):
        for frame in [-1, 8, True, '0']:
            with self.subTest(frame=frame):
                self.check_invalid(lambda g: g['frames'][0].update(frame=frame), 'unknown required pose')

    def test_explicit_cloth_torso_scale_is_finite_bounded_and_inspection_only(self):
        guide = copy.deepcopy(self.guide)
        guide['torso_scale'] = [0.5, 0.4]
        self.assertFalse(validate(guide, self.required)['ready_for_wardrobe'])
        for scale in [[float('nan'), 0.4], [0.5, 0], [0.5, 4.1], [0.5]]:
            self.check_invalid(lambda g: g.update(torso_scale=scale), 'torso_scale|torso scale')

    def test_source_and_target_bones_must_have_finite_nonzero_geometry(self):
        for name in ['source_arms', 'target_arms']:
            with self.subTest(name=name):
                self.check_invalid(lambda g: g['frames'][0][name][0][1].__setitem__(0, float('nan')), 'finite numbers')
                self.check_invalid(lambda g: g['frames'][0][name][0].__setitem__(1, g['frames'][0][name][0][0][:]), 'zero-length')

    def test_changed_atlas_requires_review_instead_of_silent_rebind(self):
        self.check_invalid(lambda g: g.update(atlas_sha256='0' * 64), 'source changed')
        self.check_invalid(lambda g: g.update(atlas_size=[1560, 1006]), 'dimensions disagree')

    def test_head_and_feet_cannot_lose_their_ownership_contract(self):
        for name in ['head', 'feet']:
            self.check_invalid(lambda g: g['frames'][0]['protection'].pop(name), 'head and foot ownership')
        self.check_invalid(lambda g: g['frames'][0]['protection'].update(head=[-1, 0, 280, 192]), 'outside fixed')

    def test_invalid_roots_or_source_regions_are_rejected(self):
        self.check_invalid(lambda g: g['frames'][0].update(source_root=[400, 210]), 'outside its fixed canvas')
        self.check_invalid(lambda g: g['frames'][0].update(atlas_region=[1500, 0, 391, 503]), 'outside the atlas')

    def test_preview_cannot_promote_itself_to_a_live_outfit(self):
        self.check_invalid(lambda g: g.update(status='production'), 'inspection_only')

    def test_malformed_cel_or_guides_fail_before_engine_dispatch(self):
        self.check_invalid(lambda g: g['frames'].__setitem__(0, None), 'must be an object')
        self.check_invalid(lambda g: g['frames'][0].update(action=[]), 'unknown required pose')
        self.check_invalid(lambda g: g['frames'][0].update(part_order=[None]), 'sleeve order')
        self.check_invalid(lambda g: g['frames'][0].update(protection_spans=[[400, 0, 1]]), 'outside fixed')
        self.check_invalid(lambda g: g['frames'][0].update(target_arms=[]), 'both sleeve guides')
        self.check_invalid(lambda g: g['frames'][0].update(source_pixel_sha256='unknown'), 'wearer signature')

if __name__ == '__main__':
    unittest.main()
