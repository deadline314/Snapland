import copy
import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('validator', ROOT / 'tools/verify_design.py')
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)


class ParkTests(unittest.TestCase):
    def setUp(self):
        self.data = v.load(ROOT, 'design/01-park/park.json')

    def test_approved_gates_are_reachable(self):
        v.validate_park(self.data)

    def test_unreachable_gate_rejected(self):
        self.data['zones'][1]['threshold'] = 500
        with self.assertRaises(ValueError):
            v.validate_park(self.data)

    def test_devil_requirement_rejected(self):
        self.data['final']['requires_devil'] = True
        with self.assertRaisesRegex(ValueError, 'devil'):
            v.validate_park(self.data)

    def test_spending_collection_rejected(self):
        self.data['unlock_consumes_photos'] = True
        with self.assertRaises(ValueError):
            v.validate_park(self.data)

    def test_ending_cannot_require_full_collection(self):
        self.data['normal_ending']['threshold'] = 180
        with self.assertRaises(ValueError):
            v.validate_park(self.data)


class GameTests(unittest.TestCase):
    def setUp(self):
        self.data = v.load(ROOT, 'design/02-minigames/catalog.json')
        self.refs = {r['id'] for r in v.load(ROOT, 'design/00-principles/references.json')['references']}

    def test_complete_catalog_accepted(self):
        v.validate_games(self.data, self.refs)

    def test_duplicate_id_rejected(self):
        self.data['games'][1]['id'] = self.data['games'][0]['id']
        with self.assertRaises(ValueError):
            v.validate_games(self.data, self.refs)

    def test_missing_player_choice_rejected(self):
        self.data['games'][0]['choice'] = ' '
        with self.assertRaisesRegex(ValueError, 'choice'):
            v.validate_games(self.data, self.refs)

    def test_variants_cannot_inflate_game_count(self):
        self.data['games'].append(copy.deepcopy(self.data['games'][0]))
        with self.assertRaises(ValueError):
            v.validate_games(self.data, self.refs)

    def test_copy_of_mechanics_rejected(self):
        for field in ('action', 'goal', 'choice'):
            self.data['games'][1][field] = self.data['games'][0][field]
        with self.assertRaisesRegex(ValueError, 'duplicate mechanics'):
            v.validate_games(self.data, self.refs)

    def test_untraceable_reference_rejected(self):
        self.data['games'][0]['reference'] = 'invented'
        with self.assertRaisesRegex(ValueError, 'source'):
            v.validate_games(self.data, self.refs)

    def test_missing_ai_and_revision_reason_rejected(self):
        for field in ('ai', 'revision_reason', 'demon_assist_policy'):
            with self.subTest(field=field):
                broken = copy.deepcopy(self.data)
                broken['games'][12].pop(field)
                with self.assertRaisesRegex(ValueError, field):
                    v.validate_games(broken, self.refs)

    def test_unbuilt_games_cannot_claim_runtime(self):
        self.data['games'][12]['implementation'] = 'single_player_runtime_needs_full_acceptance'
        with self.assertRaisesRegex(ValueError, 'scope'):
            v.validate_games(self.data, self.refs)

    def test_prototypes_must_be_six_distinct_existing_games(self):
        for ids in (['game-001'] * 6, ['game-001'], self.data['prototype_order'][:5] + ['game-999']):
            with self.subTest(ids=ids):
                self.data['prototype_order'] = ids
                with self.assertRaisesRegex(ValueError, 'prototype'):
                    v.validate_games(self.data, self.refs)

    def test_first_park_matches_current_single_player_rules(self):
        runtime = v.load(ROOT, 'game/data/welcome_games.json')
        v.validate_runtime_game_alignment(self.data, runtime)
        self.data['games'][0]['demon'] = 'a different qualification rule'
        with self.assertRaisesRegex(ValueError, 'runtime demon drift'):
            v.validate_runtime_game_alignment(self.data, runtime)


class StoryTests(unittest.TestCase):
    def setUp(self):
        self.q = v.load(ROOT, 'design/03-story/quests.json')
        self.e = v.load(ROOT, 'design/03-story/exploration.json')

    def test_complete_story_accepted(self):
        v.validate_story(self.q, self.e)

    def test_dependency_cycle_rejected(self):
        group = [r for r in self.q['quests'] if r['zone'] == 'welcome']
        group[0]['requires'] = [group[1]['id']]
        group[1]['requires'] = [group[0]['id']]
        with self.assertRaisesRegex(ValueError, 'cycle'):
            v.validate_story(self.q, self.e)

    def test_later_zone_dependency_rejected(self):
        early = next(r for r in self.q['quests'] if r['zone'] == 'welcome')
        late = next(r for r in self.q['quests'] if r['zone'] == 'cinema')
        early['requires'] = [late['id']]
        with self.assertRaisesRegex(ValueError, 'cross-zone'):
            v.validate_story(self.q, self.e)

    def test_duplicate_photo_reward_rejected(self):
        self.q['quests'][1]['reward_photo'] = self.q['quests'][0]['reward_photo']
        with self.assertRaisesRegex(ValueError, 'reward'):
            v.validate_story(self.q, self.e)

    def test_unknown_prerequisite_rejected(self):
        self.e['events'][0]['requires'] = ['theatre-win']
        with self.assertRaisesRegex(ValueError, 'unknown prerequisite'):
            v.validate_story(self.q, self.e)



class StoryStructureTests(unittest.TestCase):
    def setUp(self):
        self.data = v.load(ROOT, 'design/03-story/story-structure.json')
        self.park = v.load(ROOT, 'design/01-park/park.json')
        self.runtime = v.load(ROOT, 'game/data/first_park_story.json')

    def validate(self):
        v.validate_story_structure(self.data, self.park, self.runtime)

    def test_current_design_and_runtime_scope_agree(self):
        self.validate()

    def test_missing_character_rejected(self):
        self.data['characters'].pop()
        with self.assertRaisesRegex(ValueError, 'six characters'):
            self.validate()

    def test_unknown_act_cast_rejected(self):
        self.data['acts'][0]['cast'].append('missing')
        with self.assertRaisesRegex(ValueError, 'cast'):
            self.validate()

    def test_full_collection_cannot_replace_ordinary_ending(self):
        self.data['normal_ending']['threshold'] = 180
        with self.assertRaisesRegex(ValueError, 'normal ending'):
            self.validate()

    def test_normal_ending_cannot_depend_on_optional_finale(self):
        self.data['acts'][2]['requires'] = ['premiere']
        with self.assertRaisesRegex(ValueError, 'prerequisite'):
            self.validate()

    def test_finale_cannot_borrow_devil_card_count(self):
        self.data['optional_final']['normal_required'] = 120
        with self.assertRaisesRegex(ValueError, 'ordinary photos'):
            self.validate()

    def test_finale_cannot_require_devil_cards_or_share_authentication_album(self):
        for field, value in [('requires_devil', True), ('separate_album', False)]:
            with self.subTest(field=field):
                broken = copy.deepcopy(self.data)
                broken['optional_final'][field] = value
                with self.assertRaisesRegex(ValueError, 'optional finale'):
                    v.validate_story_structure(broken, self.park, self.runtime)

    def test_recovery_and_late_join_cannot_be_removed(self):
        for field in ('permanent_sources', 'replay_missing_steps', 'free_prop_recovery', 'single_player_completion', 'late_join_replay'):
            with self.subTest(field=field):
                broken = copy.deepcopy(self.data)
                broken['quest_event_policy'][field] = False
                with self.assertRaisesRegex(ValueError, field):
                    v.validate_story_structure(broken, self.park, self.runtime)

    def test_ai_paid_randomness_and_host_only_rewards_rejected(self):
        for field, value in [('required_ai_level', 'hard'), ('paid_random_reward', True), ('reward_owner', 'host'), ('cross_zone_prerequisites', True)]:
            with self.subTest(field=field):
                broken = copy.deepcopy(self.data)
                broken['quest_event_policy'][field] = value
                with self.assertRaisesRegex(ValueError, 'story policy'):
                    v.validate_story_structure(broken, self.park, self.runtime)

    def test_design_cannot_claim_all_regions_implemented(self):
        self.data['runtime_scope']['all_ten_zone_story_implemented'] = True
        with self.assertRaisesRegex(ValueError, 'story scope'):
            self.validate()

    def test_runtime_character_name_mismatch_rejected(self):
        self.data['characters'][0]['name'] = 'different character'
        with self.assertRaisesRegex(ValueError, 'character name'):
            self.validate()


class ItemTests(unittest.TestCase):
    def setUp(self):
        self.data = v.load(ROOT, 'design/04-items/itemdefs.json')

    def test_complete_items_accepted(self):
        v.validate_items(self.data)

    def test_duplicate_item_id_rejected(self):
        self.data[1]['itemdefid'] = self.data[0]['itemdefid']
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            v.validate_items(self.data)

    def test_market_activation_rejected(self):
        self.data[0]['marketable'] = True
        with self.assertRaisesRegex(ValueError, 'economy'):
            v.validate_items(self.data)

    def test_boolean_definition_id_rejected(self):
        self.data[0]['itemdefid'] = True
        with self.assertRaisesRegex(ValueError, 'definition id'):
            v.validate_items(self.data)

    def test_wrong_game_mapping_rejected(self):
        self.data[0]['snapland_game'] = 'game-128'
        with self.assertRaisesRegex(ValueError, 'mapping'):
            v.validate_items(self.data)


class EvidenceAndRuntimeTests(unittest.TestCase):
    def test_missing_local_link_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'README.md').write_text('[missing](missing.md)', encoding='utf-8')
            (root / 'AGENTS.md').write_text('rules', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'missing'):
                v.validate_links(root)

    def test_existing_link_accepted(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'README.md').write_text('[rules](AGENTS.md)', encoding='utf-8')
            (root / 'AGENTS.md').write_text('rules', encoding='utf-8')
            v.validate_links(root)

    def test_runtime_files_require_real_test_configuration(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'tools').mkdir()
            guard = root / 'tools/check_runtime_tests.py'
            guard.write_text((ROOT / 'tools/check_runtime_tests.py').read_text(encoding='utf-8'), encoding='utf-8')
            before = subprocess.run([sys.executable, str(guard)], capture_output=True, text=True)
            self.assertEqual(before.returncode, 0, before.stderr)
            (root / 'player.gd').write_text('extends Node', encoding='utf-8')
            after = subprocess.run([sys.executable, str(guard)], capture_output=True, text=True)
            self.assertEqual(after.returncode, 1)
            self.assertIn('actual runtime test suite', after.stderr)


if __name__ == '__main__':
    unittest.main()
