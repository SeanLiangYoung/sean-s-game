#!/usr/bin/env python3
"""Verify frozen content comparisons and expose region/build tradeoffs."""
import argparse
import hashlib
import json
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ('cohort', 'region', 'seed', 'resource', 'build', 'threat', 'captain', 'profile', 'affix', 'affix_slot')
INPUTS = ('raw_party', 'map', 'relics', 'equipment', 'xp_budget_per_actor', 'gear_silver')
COMBAT_FILES = ('rules.gd', 'talents.gd', 'battlefield.gd', 'enemy_ai.gd', 'enemy_skills.gd',
                'regions.gd', 'region_combat.gd', 'relics.gd', 'relic_expansion.gd', 'professions.gd', 'characters.gd')


def aggregate(rows):
    wins = [r for r in rows if r['win']]
    return {'cases': len(rows), 'wins': len(wins), 'win_rate': len(wins) / len(rows) if rows else None,
            'deaths': sum(r['deaths'] for r in rows), 'rounds': sum(r['rounds'] for r in rows),
            'win_mean_hp': sum(r['hp'] for r in wins) / len(wins) if wins else None,
            'win_mean_mp': sum(r['mp'] for r in wins) / len(wins) if wins else None,
            'win_mean_rounds': sum(r['rounds'] for r in wins) / len(wins) if wins else None,
            'healing_observed': sum(r['healing_observed'] for r in rows),
            'cleanses': sum(r['cleanses'] for r in rows)}


def load_version(directory, label):
    rows = []
    report_metadata = []
    for driver, expected in [('region-retune', 768), ('region-variants', 240)]:
        for suffix in ['', '-holdout']:
            path = directory / 'artifacts' / f'{driver}-{label}{suffix}.json'
            report = json.loads(path.read_text())
            assert report['valid'] and not report['stale'], path
            assert report['completed_cases'] == report['expected_cases'] == expected
            assert report['invalid_actions'] == report['stalls'] == report['unfinished'] == 0
            assert not report['quick'] and not report.get('tuning', False)
            for source, expected_hash in report['source_hashes'].items():
                assert hashlib.sha256((directory / source).read_bytes()).hexdigest() == expected_hash, f'Frozen source changed: {source}'
            rows.extend(report['results'])
            report_metadata.append({'report': path.name, 'cases': expected, 'valid': True})
    return rows, report_metadata


def compare(base_dir, final_dir, personal_dir=None):
    baseline, base_reports = load_version(base_dir, 'baseline')
    final, final_reports = load_version(final_dir, 'final')
    delta_reports = []
    accounting = {'baseline_executed': len(baseline), 'first_pass_executed': len(final),
                  'personal_delta_executed': 0, 'unchanged_final_reused': 0}
    workspace_version = final_dir
    if personal_dir is not None:
        # Prove the only combat-data delta is ward_6's wearer recovery cost.
        for filename in COMBAT_FILES:
            if filename != 'relic_expansion.gd':
                assert (final_dir / 'game' / filename).read_bytes() == (personal_dir / 'game' / filename).read_bytes(), f'Unexpected delta: {filename}'
        before_lines = (final_dir / 'game/relic_expansion.gd').read_text().splitlines()
        after_lines = (personal_dir / 'game/relic_expansion.gd').read_text().splitlines()
        assert len(before_lines) == len(after_lines)
        differences = [(a, b) for a, b in zip(before_lines, after_lines) if a != b]
        assert len(differences) == 1 and all('"ward_6":' in line for line in differences[0])
        before_item = json.loads('{' + differences[0][0].strip().rstrip(',') + '}')['ward_6']
        after_item = json.loads('{' + differences[0][1].strip().rstrip(',') + '}')['ward_6']
        assert after_item['mods']['healing_pct'] < 0
        reduced_mods = dict(after_item['mods']); reduced_mods.pop('healing_pct')
        assert before_item['mods'] == reduced_mods
        assert {k:v for k,v in before_item.items() if k not in ('mods','risk')} == {k:v for k,v in after_item.items() if k not in ('mods','risk')}
        replacements = []
        for suffix in ['', '-holdout']:
            path = personal_dir / 'artifacts' / f'region-personal-final{suffix}.json'
            report = json.loads(path.read_text())
            assert report['valid'] and not report['stale'] and report['completed_cases'] == report['expected_cases'] == 120
            assert report['invalid_actions'] == report['stalls'] == report['unfinished'] == 0
            for source, expected_hash in report['source_hashes'].items():
                assert hashlib.sha256((personal_dir / source).read_bytes()).hexdigest() == expected_hash, source
            replacements.extend(report['results']);delta_reports.append({'report':path.name,'cases':120,'valid':True})
        changed_keys = {tuple(row[f] for f in FIELDS) for row in final if any(entry['id']=='ward_6' for entry in row['relics'])}
        replacement_keys = {tuple(row[f] for f in FIELDS) for row in replacements}
        assert changed_keys == replacement_keys and len(changed_keys) == 240, 'Every affected input must be replayed'
        unchanged = [row for row in final if tuple(row[f] for f in FIELDS) not in changed_keys]
        assert all(all(entry['id']!='ward_6' for entry in row['relics']) for row in unchanged)
        accounting['personal_delta_executed'] = len(replacements)
        accounting['unchanged_final_reused'] = len(unchanged)
        final = unchanged + replacements
        workspace_version = personal_dir
    key = lambda row: tuple(row[f] for f in FIELDS)
    old = {key(r): r for r in baseline}
    new = {key(r): r for r in final}
    assert len(old) == len(baseline) == len(new) == len(final) == 2016
    assert old.keys() == new.keys(), 'Mismatched scenario matrix'
    for scenario, before in old.items():
        after = new[scenario]
        for field in INPUTS:
            assert before[field] == after[field], f'Changed funded input {field}: {scenario}'
        # Barrier payloads are deliberately tuned; deployment, HP, power and affixes must stay paired.
        for a, b in zip(before['initial_enemies'], after['initial_enemies']):
            for field in ('id', 'cell', 'max_hp', 'hp', 'power', 'base_enemy_power', 'armor', 'speed', 'range', 'affix'):
                assert a.get(field) == b.get(field), f'Changed enemy start {field}: {scenario}'
    for filename in COMBAT_FILES:
        assert (ROOT / 'game' / filename).read_bytes() == (workspace_version / 'game' / filename).read_bytes(), f'Workspace combat changed: {filename}'
    groups = {}
    for field in ('region', 'build', 'cohort', 'resource', 'captain'):
        groups[field] = {value: {'baseline': aggregate([r for r in baseline if r[field] == value]),
                                 'final': aggregate([r for r in final if r[field] == value])}
                         for value in sorted({r[field] for r in baseline})}
    region_builds = {}
    for region in sorted({r['region'] for r in baseline}):
        region_builds[region] = {build: {'baseline': aggregate([r for r in baseline if r['region'] == region and r['build'] == build]),
                                       'final': aggregate([r for r in final if r['region'] == region and r['build'] == build])}
                                for build in sorted({r['build'] for r in baseline})}
    regional_direction = {region: groups['region'][region]['final']['wins'] - groups['region'][region]['baseline']['wins']
                          for region in ('marsh', 'frost', 'ruins')}
    crossed = [r for r in final if r['build'].startswith('cross_blood_ward')]
    passed = (regional_direction['marsh'] >= 0 and regional_direction['frost'] < 0 and regional_direction['ruins'] < 0)
    return {'games': len(baseline) + len(final), 'paired_scenarios': len(old),
            'baseline_reports': base_reports, 'first_pass_reports': final_reports, 'personal_delta_reports': delta_reports, 'execution_accounting': accounting,
            'overall': {'baseline': aggregate(baseline), 'final': aggregate(final)},
            'groups': groups, 'region_builds': region_builds,
            'region_player_win_deltas': regional_direction, 'regional_direction_gate_pass': passed,
            'blood_ward_final': aggregate(crossed),
            'paired_reversals': {'earlier_win_now_loss': sum(before['win'] and not new[k]['win'] for k, before in old.items()),
                                 'earlier_loss_now_win': sum(not before['win'] and new[k]['win'] for k, before in old.items())},
            'measurement': 'Win HP/MP/rounds exclude defeats; healing_observed is net positive HP change across actions, not attributed healing.',
            'limits': 'Normal overall difficulty, fixed two funded policies, core and focus budgets differ, deterministic stratified cases; no claim of all item permutations or human win rates.'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--final', type=Path, required=True)
    parser.add_argument('--personal', type=Path)
    args = parser.parse_args()
    result = compare(args.baseline, args.final, args.personal)
    (ROOT / 'artifacts/region-retune-summary.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ('games', 'paired_scenarios', 'overall', 'region_player_win_deltas', 'regional_direction_gate_pass', 'blood_ward_final')}, ensure_ascii=False, indent=2))
    return 0 if result['regional_direction_gate_pass'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
