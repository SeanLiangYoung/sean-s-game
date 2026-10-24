#!/usr/bin/env python3
"""Validate paired study evidence and summarize player difficulty without hiding regressions."""
import hashlib
import json
import pathlib
import sys
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parents[1]
CASE_FIELDS = ('cohort', 'region', 'seed', 'resource', 'build', 'threat',
               'affix', 'mix', 'profile', 'affix_slot')
START_FIELDS = ('initial_party', 'initial_enemies', 'map', 'relics', 'training')
POLICIES = ('classic', 'previous', 'current')


def totals(rows):
    result = {'cases': len(rows)}
    for field in ('deaths', 'rounds', 'remaining_hp', 'remaining_mp',
                  'captain_damage', 'other_damage', 'captain_hits', 'other_hits'):
        result[field] = sum(row[field] for row in rows)
    result['wins'] = sum(row['win'] for row in rows)
    result['win_rate'] = result['wins'] / len(rows) if rows else None
    return result


def summarize(paths):
    rows = []
    reports = []
    for path in paths:
        report = json.loads(path.read_text())
        assert report['valid'] and not report['stale'], f'Invalid evidence: {path}'
        assert not report['quick'] and not report['tuning'] and not report['policy_filter'], 'Full three-policy reports required'
        assert report['completed_cases'] == report['expected_cases'] == 2088
        for source, expected in report['source_hashes'].items():
            assert hashlib.sha256((ROOT / source).read_bytes()).hexdigest() == expected, f'Source changed: {source}'
        reports.append({'file': str(path.relative_to(ROOT)), 'holdout': report['holdout'], 'games': report['completed_cases']})
        rows.extend(report['results'])
    paired = defaultdict(dict)
    for row in rows:
        key = tuple(row[field] for field in CASE_FIELDS)
        assert row['policy'] not in paired[key], f'Duplicate case: {key}'
        paired[key][row['policy']] = row
    for key, group in paired.items():
        assert set(group) == set(POLICIES), f'Unpaired case: {key}'
        reference = group['classic']
        for policy in POLICIES[1:]:
            for field in START_FIELDS:
                assert group[policy][field] == reference[field], f'Unequal {field}: {key}'
    overall = {policy: totals([row for row in rows if row['policy'] == policy]) for policy in POLICIES}
    regions = {}
    resources = {}
    builds = {}
    for field, destination in (('region', regions), ('resource', resources), ('build', builds)):
        for value in sorted({row[field] for row in rows}):
            destination[value] = {policy: totals([row for row in rows if row['policy'] == policy and row[field] == value]) for policy in POLICIES}
    reversals = {}
    for policy in POLICIES[:2]:
        reversals[policy] = {
            'earlier_player_win_now_loss': sum(group[policy]['win'] and not group['current']['win'] for group in paired.values()),
            'earlier_player_loss_now_win': sum(not group[policy]['win'] and group['current']['win'] for group in paired.values()),
        }
    cohort_gates = {}
    for report in reports:
        report_rows = json.loads((ROOT / report['file']).read_text())['results']
        wins = {policy: sum(row['win'] for row in report_rows if row['policy'] == policy) for policy in POLICIES}
        regional_wins = {}
        for region in sorted({row['region'] for row in report_rows}):
            counts = {policy: sum(row['win'] for row in report_rows if row['policy'] == policy and row['region'] == region) for policy in POLICIES}
            regional_wins[region] = {'wins': counts, 'pass': counts['current'] <= min(counts['previous'], counts['classic'])}
        cohort_gates[report['file']] = {'wins': wins, 'regions': regional_wins,
                                        'pass': wins['current'] <= min(wins['previous'], wins['classic']) and all(item['pass'] for item in regional_wins.values())}
    return {'games': len(rows), 'paired_scenarios': len(paired), 'reports': reports,
            'pressure_measure': 'HP loss observed during enemy actions, including turn-transition effects; not direct damage only',
            'overall': overall, 'regions': regions, 'resources': resources, 'builds': builds, 'paired_reversals': reversals,
            'cohort_difficulty_gates': cohort_gates,
            'difficulty_gate_pass': all(row['pass'] for row in cohort_gates.values()),
            'regions_easier_than_previous': [region for region, values in regions.items() if values['current']['wins'] > values['previous']['wins']],
            'builds_easier_than_previous': [build for build, values in builds.items() if values['current']['wins'] > values['previous']['wins']],
            'limits': 'Fixed player policy; stratified combinations, not every Cartesian relic/skill combination; no claim of human win rates.'}


def main():
    paths = [pathlib.Path(arg).resolve() for arg in sys.argv[1:]] or [ROOT / 'artifacts/enemy-coordination-final.json', ROOT / 'artifacts/enemy-coordination-final-holdout.json']
    result = summarize(paths)
    destination = ROOT / 'artifacts/enemy-coordination-summary.json'
    destination.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['difficulty_gate_pass'] else 1


if __name__ == '__main__':
    sys.exit(main())
