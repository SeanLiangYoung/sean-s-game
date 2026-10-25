#!/usr/bin/env python3
"""Verify frozen content comparisons and expose region/build tradeoffs."""
import argparse
import hashlib
import json
import re
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


def compare(base_dir, final_dir):
    baseline, base_reports = load_version(base_dir, 'baseline')
    final, final_reports = load_version(final_dir, 'final')
    for filename in ('simulate_region_retune.gd','simulate_region_variants.gd','simulate_enemy_coordination.gd','simulate_boss_balance.gd','relic_mix_simulation.gd','simulate_enemy_ai.gd','enemy_ai_previous.gd'):
        assert (base_dir/'tools'/filename).read_bytes()==(final_dir/'tools'/filename).read_bytes(), f'Unequal policy tool: {filename}'
    accounting = {'baseline_executed': len(baseline), 'final_executed': len(final),
                  'unchanged_final_reused': 0}
    workspace_version = final_dir
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
    nonbattle_changes = []
    for filename in COMBAT_FILES:
        live = (ROOT / 'game' / filename).read_text()
        frozen = (workspace_version / 'game' / filename).read_text()
        if live == frozen:continue
        # Reward drafting is not called by these fixed-loadout battle studies.
        # Permit only that complete function to differ, never catalog/stat logic.
        if filename == 'relics.gd':
            pattern = r"(?ms)^static func draft_rewards\(.*?(?=^(?:static )?func |\Z)"
            live_body, a = re.subn(pattern, '', live, count=1)
            frozen_body, b = re.subn(pattern, '', frozen, count=1)
            assert a == b == 1 and live_body == frozen_body, 'Relic battle logic changed'
            callers = [ROOT / 'game' / f for f in COMBAT_FILES if f != 'relics.gd']
            callers += [ROOT / 'tools' / f for f in ('simulate_region_retune.gd','simulate_region_variants.gd','simulate_region_personal.gd','simulate_boss_balance.gd','simulate_enemy_coordination.gd','relic_mix_simulation.gd','simulate_enemy_ai.gd','enemy_ai_previous.gd')]
            assert all(not re.search(r"\bdraft_rewards\s*\(", f.read_text()) for f in callers)
            nonbattle_changes.append('relics.gd:draft_rewards only; fixed-loadout studies do not call it')
        else:
            raise AssertionError(f'Workspace combat changed: {filename}')
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
    spread = {}
    for version in ('baseline','final'):
        rates=[groups['region'][region][version]['win_rate'] for region in groups['region']]
        spread[version]={'min_win_rate':min(rates),'max_win_rate':max(rates),'spread_percentage_points':100*(max(rates)-min(rates))}
    crossed = [r for r in final if r['build'].startswith('cross_blood_ward')]
    # The core hunt and blood/ward templates happen to share identical affixes,
    # not merely the same map. Check exact equality before comparing builds.
    matchup_fields = tuple(field for field in FIELDS if field != 'build')
    matchup_key = lambda row: tuple(row[field] for field in matchup_fields)
    hunts = {matchup_key(row): row for row in final if row['cohort']=='core' and row['build']=='hunt'}
    counterexamples = {}
    for build in sorted({row['build'] for row in crossed}):
        pairs = [(row, hunts[matchup_key(row)]) for row in crossed if row['cohort']=='core' and row['build']==build and matchup_key(row) in hunts]
        assert len(pairs)==96
        assert all(a['raw_party']==b['raw_party'] and a['map']==b['map'] and a['initial_enemies']==b['initial_enemies'] and a['gear_silver']==b['gear_silver'] for a,b in pairs)
        both = [(a,b) for a,b in pairs if a['win'] and b['win']]
        counterexamples[build] = {'exact_paired_cases':len(pairs), 'both_won':len(both),
                                  'hunt_won_cross_lost':[{'region':a['region'],'seed':a['seed'],'resource':a['resource'],'threat':a['threat']} for a,b in pairs if not a['win'] and b['win']],
                                  'cross_more_deaths_when_both_won':sum(a['deaths']>b['deaths'] for a,b in both),
                                  'cross_slower_when_both_won':sum(a['rounds']>b['rounds'] for a,b in both),
                                  'cross_less_hp_when_both_won':sum(a['hp']<b['hp'] for a,b in both)}
    passed = (regional_direction['marsh'] >= 0 and regional_direction['frost'] < 0 and regional_direction['ruins'] < 0)
    return {'status':'verified_corrected_snapshot', 'policy_tools_identical':True, 'games': len(baseline) + len(final), 'paired_scenarios': len(old),
            'baseline_reports': base_reports, 'final_reports': final_reports, 'execution_accounting': accounting,
            'overall': {'baseline': aggregate(baseline), 'final': aggregate(final)},
            'groups': groups, 'region_builds': region_builds, 'workspace_nonbattle_changes':nonbattle_changes,
            'region_player_win_deltas': regional_direction, 'regional_direction_gate_pass': passed, 'region_win_rate_spread':spread,
            'blood_ward_final': aggregate(crossed), 'exact_build_matchups_against_hunt':counterexamples,
            'paired_reversals': {'earlier_win_now_loss': sum(before['win'] and not new[k]['win'] for k, before in old.items()),
                                 'earlier_loss_now_win': sum(not before['win'] and new[k]['win'] for k, before in old.items())},
            'measurement': 'Win HP/MP/rounds exclude defeats; healing_observed is net positive HP change across actions, not attributed healing.',
            'limits': 'Normal overall difficulty, fixed two funded policies, core and focus budgets differ, deterministic stratified cases; no claim of all item permutations or human win rates.'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--final', type=Path, required=True)
    args = parser.parse_args()
    result = compare(args.baseline, args.final)
    (ROOT / 'artifacts/region-retune-summary.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ('games', 'paired_scenarios', 'overall', 'region_player_win_deltas', 'regional_direction_gate_pass', 'blood_ward_final')}, ensure_ascii=False, indent=2))
    return 0 if result['regional_direction_gate_pass'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
