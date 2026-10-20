"""Validate design data and reachability, never claim gameplay quality."""
import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
ZONES = ('welcome', 'harbor', 'candy', 'nightmarket', 'circus', 'toy', 'garden', 'hotel', 'sky', 'cinema')
CORES = {'掌握', '取捨', '預測', '創意', '協調', '節奏'}
GAME_FIELDS = ('id', 'name', 'zone', 'core', 'action', 'goal', 'choice', 'feedback', 'variation', 'solo', 'multi', 'ai', 'demon', 'demon_assist_policy', 'variant', 'assist', 'test', 'reference', 'revision', 'revision_reason', 'presentation', 'implementation')


def load(root, relative):
    return json.loads((root / relative).read_text(encoding='utf-8-sig'))


def check(condition, message):
    if not condition:
        raise ValueError(message)


def nonempty(rows, fields, label):
    check(isinstance(rows, list) and bool(rows), f'{label}: missing list')
    for row in rows:
        check(isinstance(row, dict), f'{label}: invalid record')
        for field in fields:
            check(isinstance(row.get(field), str) and row[field].strip(), f'{label} {row.get("id")}: missing {field}')


def unique_ids(rows, label):
    ids = [r['id'] for r in rows]
    check(len(set(ids)) == len(ids), f'{label}: duplicate ids')


def validate_park(data):
    rows = data['zones']
    nonempty(rows, ('id', 'name', 'theme', 'layout', 'exploration', 'rift', 'rift_rule'), 'park')
    unique_ids(rows, 'park')
    check(tuple(r['id'] for r in rows) == ZONES, 'park: zone order/set mismatch')
    check(data['max_seats'] == 4, 'park: 1–4 seat contract')
    check(data['ai_levels'] == ['簡單', '中等', '困難', '惡魔'], 'park: AI tiers')
    counts = data['collectible_counts']
    check([counts[k] for k in ('game', 'explore', 'story', 'quest')] == [12, 3, 1, 2], 'park: source counts')
    check(sum(counts[k] for k in ('game', 'explore', 'story', 'quest')) == 18, 'park: per-zone total')
    check(counts['normal_total'] == 180 and counts['devil_total'] == 120, 'park: collection totals')
    check(counts['normal_per_zone'] == 18 and counts['devil_per_zone'] == 12, 'park: collection sizes')
    expected = [0, 6, 6, 6, 30, 30, 30, 60, 60, 60]
    check([r['threshold'] for r in rows] == expected, 'park: approved staged gates')
    available = 0
    for threshold in sorted(set(expected)):
        check(available >= threshold, f'park: unreachable gate {threshold}, only {available} available')
        group = [r for r in rows if r['threshold'] == threshold]
        check(all(r['normal_count'] == 18 and r['devil_count'] == 12 for r in group), 'park: zone counts')
        available += sum(r['normal_count'] for r in group)
    check(available == 180 and data['final']['normal_required'] == available, 'park: final collection gate')
    check(data['final']['id'] == 'theatre' and data['final']['game_count'] == 8, 'park: final games')
    check(data['final']['requires_devil'] is False, 'park: final cannot require devil photos')
    check(data['normal_ending'] == {'threshold': 60, 'visited_zones': 10, 'requires_devil': False}, 'park: normal ending')
    check(data['unlock_consumes_photos'] is False and data['assisted_collection_equal'] is True, 'park: inclusive collection')
    check(counts['explore'] + counts['story'] + counts['quest'] >= 6, 'park: first expansion without game wins')


def validate_games(data, refs):
    check(data.get('status') == 'design_spec_not_playtested', 'games: design cannot claim playtest acceptance')
    rows = data['games']
    nonempty(rows, GAME_FIELDS, 'games')
    unique_ids(rows, 'games')
    check(len(rows) == 128, 'games: expected 128 base games')
    check({r['id'] for r in rows} == {f'game-{i:03d}' for i in range(1, 129)}, 'games: id coverage')
    counts = Counter(r['zone'] for r in rows)
    check(counts == Counter({**{z: 12 for z in ZONES}, 'theatre': 8}), 'games: zone counts')
    check(len({r['name'] for r in rows}) == 128, 'games: duplicate names')
    signatures = [(r['action'].strip(), r['goal'].strip(), r['choice'].strip()) for r in rows]
    check(len(set(signatures)) == 128, 'games: exact duplicate mechanics')
    for i, row in enumerate(sorted(rows, key=lambda r: r['id']), 1):
        expected = ZONES[(i - 1) // 12] if i <= 120 else 'theatre'
        check(row['zone'] == expected, f'games {row["id"]}: numbering zone mismatch')
        check(row['core'] in CORES, f'games {row["id"]}: unknown core')
        check(row['reference'] in refs, f'games {row["id"]}: missing source')
        check(row['revision'] in {'保留', '重設', '替換'}, f'games {row["id"]}: revision status')
        expected_state = 'single_player_runtime_needs_full_acceptance' if i <= 12 else 'design_only_not_playtested'
        check(row['implementation'] == expected_state, f'games {row["id"]}: implementation scope mismatch')
    check(CORES.issubset({r['core'] for r in rows}), 'games: missing fun families')
    prototypes = data.get('prototype_order')
    check(isinstance(prototypes, list) and len(prototypes) == 6 and len(set(prototypes)) == 6,
          'games: six distinct prototypes required')
    check(all(key in {r['id'] for r in rows} for key in prototypes), 'games: unknown prototype')


def validate_runtime_game_alignment(data, runtime):
    """The catalogue may plan modes, but cannot silently redefine live solo rules."""
    first = [row for row in data['games'] if row['zone'] == 'welcome']
    check(len(first) == len(runtime) == 12, 'games: first-park runtime coverage')
    for row, live in zip(sorted(first, key=lambda r: r['id']), sorted(runtime, key=lambda r: r['id'])):
        for field, live_field in [('id', 'id'), ('name', 'name'), ('action', 'instructions'),
                                  ('goal', 'ordinary'), ('demon', 'devil'), ('runtime_mode', 'mode')]:
            check(row.get(field) == live[live_field], f'games {row["id"]}: runtime {field} drift')


def validate_story(quests, events):
    q = quests['quests']
    e = events['events']
    nonempty(q, ('id', 'zone', 'title', 'trigger', 'reward_photo', 'reward_extra', 'recovery', 'multiplayer'), 'quests')
    nonempty(e, ('id', 'zone', 'title', 'interaction', 'reward_photo', 'hint', 'recovery', 'multiplayer'), 'exploration')
    check(len(q) == 20 and len(e) == 30, 'story: expected 20 quests and 30 exploration events')
    check({r['id'] for r in q} == {f'quest-{i:03d}' for i in range(1, 21)}, 'quests: id coverage')
    check({r['id'] for r in e} == {f'explore-{i:03d}' for i in range(1, 31)}, 'exploration: id coverage')
    unique_ids(q + e, 'story')
    check(Counter(r['zone'] for r in q) == Counter({z: 2 for z in ZONES}), 'quests: per-zone coverage')
    check(Counter(r['zone'] for r in e) == Counter({z: 3 for z in ZONES}), 'exploration: per-zone coverage')
    expected_photos = {f'photo-{z}-quest-{i}' for z in ZONES for i in (1, 2)} | {f'photo-{z}-explore-{i}' for z in ZONES for i in (1, 2, 3)}
    check({r['reward_photo'] for r in q + e} == expected_photos, 'story: reward coverage or duplicates')
    for row in q:
        check(isinstance(row.get('steps'), list) and len(row['steps']) == 3 and all(isinstance(s, str) and s.strip() for s in row['steps']), f'quest {row["id"]}: three observable steps required')
    records = {r['id']: r for r in q + e}
    for row in records.values():
        check(isinstance(row.get('requires'), list), f'story {row["id"]}: explicit prerequisites required')
        for dep in row['requires']:
            check(dep in records, f'story {row["id"]}: unknown prerequisite {dep}')
            check(records[dep]['zone'] == row['zone'], f'story {row["id"]}: cross-zone collection dependency')
    visiting, done = set(), set()
    def visit(key):
        check(key not in visiting, f'story: prerequisite cycle at {key}')
        if key in done:
            return
        visiting.add(key)
        for dep in records[key]['requires']:
            visit(dep)
        visiting.remove(key)
        done.add(key)
    for key in records:
        visit(key)



def validate_story_structure(data, park, runtime):
    check(data.get('status') == 'design_spec_not_playtested', 'story structure: explicit design scope required')
    characters = data.get('characters', [])
    check(isinstance(characters, list) and len(characters) == 6, 'story structure: six characters required')
    nonempty(characters, ('id', 'name', 'role', 'motivation', 'comic_beat'), 'story characters')
    unique_ids(characters, 'story characters')
    check(len({c['name'] for c in characters}) == 6, 'story characters: duplicate names')
    character_ids = {c['id'] for c in characters}
    acts = data.get('acts', [])
    kinds = ['onboarding', 'free_roam', 'normal_ending', 'optional_final']
    check(isinstance(acts, list) and len(acts) == 4, 'story structure: four acts required')
    nonempty(acts, ('id', 'kind', 'title', 'player_action', 'payoff'), 'story acts')
    unique_ids(acts, 'story acts')
    check([a['kind'] for a in acts] == kinds, 'story structure: ordinary ending must precede optional finale')
    for index, act in enumerate(acts):
        cast = act.get('cast')
        check(isinstance(cast, list) and cast and len(set(cast)) == len(cast) and set(cast) <= character_ids, 'story act: unknown or repeated cast')
        expected = [] if index == 0 else [acts[index-1]['id']]
        check(act.get('requires') == expected, 'story act: dangling, cyclic or optional-ending prerequisite')
    check(set().union(*(set(a['cast']) for a in acts)) == character_ids, 'story structure: every character needs a story role')
    ending = data.get('normal_ending', {})
    check(ending == park['normal_ending'] and type(ending.get('threshold')) is int and type(ending.get('visited_zones')) is int, 'story structure: normal ending differs from park gates')
    final = data.get('optional_final', {})
    check(type(final.get('normal_required')) is int and final['normal_required'] == park['final']['normal_required'] == park['collectible_counts']['normal_total'], 'story structure: finale must authenticate all ordinary photos')
    check(type(final.get('game_count')) is int and final['game_count'] == park['final']['game_count'], 'story structure: finale game count differs from park')
    check(final.get('requires_normal_ending') is True and final.get('requires_devil') is False and final.get('separate_album') is True, 'story structure: optional finale must follow ordinary ending with separate album, no devil gate')
    policy = data.get('quest_event_policy', {})
    for key in ('permanent_sources', 'replay_missing_steps', 'free_prop_recovery', 'single_player_completion', 'late_join_replay'):
        check(policy.get(key) is True, f'story policy: {key} must remain available')
    check(policy.get('reward_owner') == 'each_participant' and 'required_ai_level' in policy and policy['required_ai_level'] is None and policy.get('paid_random_reward') is False and policy.get('cross_zone_prerequisites') is False, 'story policy: personal rewards, no required AI, paid randomness or cross-zone gate')
    scope = data.get('runtime_scope', {})
    check(scope.get('all_ten_zone_story_implemented') is False and scope.get('implemented_zone_ids') == ['welcome'], 'story scope: ten-zone story is a design, not implemented runtime')
    check(set(scope.get('implemented_character_ids', [])) == set(runtime['characters']) <= character_ids, 'story scope: runtime cast differs from actual welcome data')
    check(set(scope.get('welcome_quest_ids', [])) == set(runtime['quest_missions']), 'story scope: runtime quests differ from actual welcome data')
    for char in characters:
        if char['id'] in runtime['characters']:
            check(char['name'] == runtime['characters'][char['id']]['name'], 'story scope: character name differs from actual welcome data')


def validate_items(rows):
    check(isinstance(rows, list) and len(rows) == 339, 'items: expected 308 photos + 30 cosmetics + currency')
    ids, keys = [], []
    for row in rows:
        ident = row.get('itemdefid')
        check(type(ident) is int and 0 < ident < 1_000_000, 'items: invalid Steam definition id')
        check(row.get('type') == 'item', 'items: invalid item type')
        for field in ('name', 'description', 'snapland_kind', 'snapland_key'):
            check(isinstance(row.get(field), str) and row[field].strip(), f'items {ident}: missing {field}')
        check(row.get('tradable') is False and row.get('marketable') is False, 'items: unauthorized economy activation')
        ids.append(ident)
        keys.append(row['snapland_key'])
    check(len(set(ids)) == len(ids) and len(set(keys)) == len(keys), 'items: duplicate definition ids/keys')
    count = Counter(r['snapland_kind'] for r in rows)
    check(count == Counter({'photo_game': 120, 'photo_explore': 30, 'photo_story': 10, 'photo_quest': 20, 'devil': 120, 'final_photo': 8, 'frame': 10, 'effect': 10, 'outfit': 10, 'currency': 1}), 'items: category totals')
    expected = {f'photo-{z}-game-{i}' for z in ZONES for i in range(1, 13)}
    expected |= {f'devil-{z}-{i}' for z in ZONES for i in range(1, 13)}
    expected |= {f'photo-{z}-{kind}-{i}' for z in ZONES for kind, size in [('explore', 3), ('story', 1), ('quest', 2)] for i in range(1, size + 1)}
    expected |= {f'photo-theatre-game-{i}' for i in range(1, 9)}
    photos = {r['snapland_key'] for r in rows if r['snapland_kind'].startswith('photo_') or r['snapland_kind'] in {'devil', 'final_photo'}}
    check(photos == expected, 'items: photo source coverage')
    for zindex, zone in enumerate(ZONES):
        for i in range(1, 13):
            for key in (f'photo-{zone}-game-{i}', f'devil-{zone}-{i}'):
                row = next(r for r in rows if r['snapland_key'] == key)
                check(row.get('snapland_game') == f'game-{zindex * 12 + i:03d}', f'items: game mapping {key}')
    for i in range(1, 9):
        row = next(r for r in rows if r['snapland_key'] == f'photo-theatre-game-{i}')
        check(row.get('snapland_game') == f'game-{120 + i}', 'items: final mapping')


def validate_links(root):
    paths = [root / 'README.md', root / 'AGENTS.md']
    paths += sorted((root / 'design').rglob('*.md')) + sorted((root / 'pm').rglob('*.md'))
    for path in paths:
        text = re.sub(r'```.*?```', '', path.read_text(encoding='utf-8-sig'), flags=re.S)
        for target in re.findall(r'!?\[[^\]\n]*\]\(([^)\n]+)\)', text):
            target = target.strip().strip('<>')
            if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', target) or target.startswith('#'):
                continue
            target = unquote(target.split('#')[0])
            if target:
                check((path.parent / target).is_file(), f'links: missing {path.relative_to(root)} -> {target}')


def run(root, scope):
    scopes = ['park', 'games', 'story', 'items', 'links'] if scope == 'all' else [scope]
    for part in scopes:
        if part == 'park':
            validate_park(load(root, 'design/01-park/park.json'))
        elif part == 'games':
            refs = {r['id'] for r in load(root, 'design/00-principles/references.json')['references']}
            data = load(root, 'design/02-minigames/catalog.json')
            validate_games(data, refs)
            validate_runtime_game_alignment(data, load(root, 'game/data/welcome_games.json'))
        elif part == 'story':
            validate_story(load(root, 'design/03-story/quests.json'), load(root, 'design/03-story/exploration.json'))
            validate_story_structure(load(root, 'design/03-story/story-structure.json'), load(root, 'design/01-park/park.json'), load(root, 'game/data/first_park_story.json'))
        elif part == 'items':
            validate_items(load(root, 'design/04-items/itemdefs.json'))
        elif part == 'links':
            validate_links(root)
        print(f'PASS {part}')
    print(f'PASS {len(scopes)} design scope(s); gameplay/playtesting not executed')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--scope', choices=['park', 'games', 'story', 'items', 'links', 'all'], default='all')
    parser.add_argument('--root', type=Path, default=ROOT)
    args = parser.parse_args()
    try:
        run(args.root.resolve(), args.scope)
    except (ValueError, KeyError, TypeError, OSError, json.JSONDecodeError) as exc:
        print(f'FAIL {exc}', file=sys.stderr)
        sys.exit(1)
