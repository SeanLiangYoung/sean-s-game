#!/usr/bin/env python3
"""Validate paired character/mixed-build experiments and write the grouped report."""
import collections
import json
import pathlib
import statistics

ROOT = pathlib.Path(__file__).resolve().parents[1]
CAPTAINS = ('shen', 'wen', 'lu')
CAPTAIN_NAMES = {'shen': '沈烬', 'wen': '闻笙', 'lu': '陆衡'}
PROFILE_NAMES = {'balanced': '均衡队', 'hunt_guard': '猎手／援护队', 'sustain_guard': '续航／援护队',
                 'control_support': '控制／支援队', 'no_medic': '无专职治疗队', 'double_medic': '双治疗队'}
FAMILY_NAMES = {'blood': '血契', 'hunt': '追猎', 'ward': '守誓', 'arcane': '秘法',
                'engine': '遗械', 'pilgrim': '生息', 'dusk': '孤影', 'command': '战阵'}
AFFECTED = {'pure_team_blood', 'pure_personal_blood', 'pure_team_command', 'pure_personal_command'}


def read_phase(label):
    chunks = [json.loads((ROOT / 'artifacts' / f'relic-mixes-{label}-{captain}.json').read_text()) for captain in CAPTAINS]
    for chunk in chunks:
        assert not chunk['changed_sources'] and not chunk['invalid_actions'] and not chunk['incomplete_battles']
        assert chunk['source_hashes'] == chunks[0]['source_hashes'], 'Different sources across captain chunks'
        assert chunk['simulation_hashes']['policy'] == chunks[0]['simulation_hashes']['policy']
        assert all(row['outcome'] for row in chunk['results']), 'Unfinished battle cannot count as defeat'
    return chunks, [row for chunk in chunks for row in chunk['results']]


def key(row):
    return tuple(row[k] for k in ('captain', 'profile', 'combo', 'region', 'seed', 'depleted'))


def stats(rows):
    wins = [r for r in rows if r['outcome'] == 'victory']
    return {'samples': len(rows), 'wins': len(wins), 'win_pct': round(100 * len(wins) / len(rows), 2),
            'mean_rounds': round(statistics.mean(r['rounds'] for r in rows), 2),
            'mean_dead': round(statistics.mean(len(r['dead']) for r in rows), 3),
            'mean_hp_in_wins': round(statistics.mean(r['hp'] for r in wins), 1) if wins else None}


def group(rows, field):
    buckets = collections.defaultdict(list)
    for row in rows:
        buckets[row[field]].append(row)
    return {name: stats(value) for name, value in buckets.items()}


def describe(name):
    if name.startswith('mix_'):
        return '＋'.join(FAMILY_NAMES[p] for p in name[4:].split('_'))
    if name.startswith('pure_team_'):
        return FAMILY_NAMES[name[10:]] + '四件全队遗物'
    if name.startswith('pure_personal_'):
        return FAMILY_NAMES[name[14:]] + '三全队＋一个人'
    return {'none': '无遗物', 'stress_action_stack': '行动点叠加', 'stress_lifesteal': '吸血／恢复叠加',
            'stress_burst': '爆发混搭', 'stress_shield': '护盾循环', 'stress_healer': '治疗核心',
            'stress_mark': '标记爆发'}.get(name, name)


def main():
    before_chunks, before = read_phase('controlled-baseline')
    after_chunks, replay = read_phase('controlled-final')
    assert len(before) == 9180 and len(replay) == 1440
    assert before_chunks[0]['simulation_hashes']['policy'] == after_chunks[0]['simulation_hashes']['policy']
    before_by_key = {key(r): r for r in before}
    assert len(before_by_key) == len(before)
    replay_by_key = {key(r): r for r in replay}
    assert len(replay_by_key) == len(replay)
    audited = [r for r in replay if r['combo'] not in AFFECTED]
    for row in audited:
        assert row == before_by_key[key(row)], f'Unchanged control/audit changed: {key(row)}'
    # Only the four-piece blood/command bonuses changed. No 2+2 case can acquire either four-piece.
    changed_sources = sorted(k for k in before_chunks[0]['source_hashes'] if before_chunks[0]['source_hashes'][k] != after_chunks[0]['source_hashes'][k])
    assert changed_sources == ['relic_expansion.gd', 'rules.gd'], changed_sources
    for row in before:
        if row['combo'] in AFFECTED:
            assert key(row) in replay_by_key
    # Combined matrix is explicit: unaffected cases are reused, not claimed as rerun battles.
    after = [replay_by_key.get(key(row), row) for row in before]
    before_groups, after_groups = group(before, 'combo'), group(after, 'combo')
    parties = {}
    for captain in CAPTAINS:
        for profile in PROFILE_NAMES:
            rows = [r for r in after if r['captain'] == captain and r['profile'] == profile]
            available = {r['combo'] for r in rows if r['combo'] != 'none' and r['outcome'] == 'victory'}
            mixed = {name for name in available if name.startswith('mix_')}
            parties[f'{captain}/{profile}'] = {**stats(rows), 'winnable_loadouts': len(available), 'winnable_pairs': len(mixed)}
    routes = json.loads((ROOT / 'artifacts' / 'mixed-routes-final.json').read_text())
    assert not routes['changed_sources'] and not routes['invalid_actions']
    assert len(routes['results']) == 36
    route_cases = collections.defaultdict(list)
    for row in routes['results']:
        assert row['failure'] in ('', 'gameover', 'defeat')
        route_cases[(row['captain'], row['profile'])].append(row)
    for values in route_cases.values():
        assert len(values) == 2 and values[0]['route_seed'] == values[1]['route_seed'] and values[0]['region'] == values[1]['region']
    summary = {'baseline_battles': len(before), 'replayed_battles': len(replay),
               'replayed_affected_battles': sum(r['combo'] in AFFECTED for r in replay), 'unchanged_audit_battles': len(audited),
               'reused_unchanged_cases': len(before) - len(replay), 'changed_sources_in_experiment': changed_sources,
               'before': stats(before), 'combined_after': stats(after),
               'combos': {name: {'before': value, 'after': after_groups[name]} for name, value in before_groups.items()},
               'parties_after': parties,
               'routes': {'samples': 36, 'clears': sum(r['cleared'] for r in routes['results']),
                          'battles': sum(len(r['battles']) for r in routes['results']),
                          'by_combo': {name: {'samples': len(rows), 'clears': sum(r['cleared'] for r in rows)}
                                       for name, rows in ((combo, [r for r in routes['results'] if r['combo'] == combo]) for combo in ('mix_hunt_arcane', 'mix_blood_pilgrim'))}}}
    (ROOT / 'artifacts' / 'relic-mixes-summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
    lines = ['# 不同角色与跨流派遗物实战记录 · 2026-10-25', '',
             '本轮使用18名实际角色（3位团长、15位同伴）的职业与专属天赋，测试18支五人队伍。正式数值对照冻结同一版本的敌方战术、首领阶段、角色与战场；没有把并行开发中的敌方策略变化混入遗物前后差异。', '',
             '## 测试范围与预算', '',
             '- 51种配置：无遗物对照、8主题各两套纯流派（4全队／3全队＋1个人）、28种主题两两2＋2代表混搭、6种高风险叠加。不是全部遗物与佩戴者排列的穷举。',
             '- 主矩阵：三团长×四队型×51配置×六区×满资源/70%生命50%法力两状态，seed21独立交叉资源。另以三团长×无专职治疗/双治疗两队型×51配置×六区、seed73满资源留出验证，共9,180场。留出队型和种子同时改变，不据此单独归因某个因素。',
             '- 每人360经验上限，所有前置合法；团长实际支出345经验，其余每人285，整队合计1,485。各队同为11件低档装备、330银币配装，仅团长有额外木盾，总基础防护一致。',
             '- 真实支付行动/法力，使用治疗、净护、援护、标记、机关、预告躲避与真实伤害预演。每次个人行动最多主动标记一次，保留主攻行动点；回归验证鸦能未移动施放狙击。',
             '- 受影响的血契/战阵四件配置全量配对复跑720场，再复跑720场无遗物及未改混搭作为一致性抽查，共1,440场。另7,740个未受影响案例复用基线，绝不算作新跑；720个未改抽查逐项完全一致。',
             '- 所有正式战斗均有结局、无非法行动、运行中源码未变。初试发现的束缚/1行动点敌人卡死结果独立保存并排除，正式对照已统一修复。', '',
             '## 具体调整', '',
             '- 战阵四件：常驻行动点+1改为每次自身行动首次直接命中+6、击杀回蓝2。督战铁令自身+1行动点保留，避免同主题把全队推到6行动点而过度压缩战斗。两件战阵及跨流派2＋2不变。',
             '- 血契四件：保留半血伤害+14，补充半血及以下承伤-2；不抵消遗物自伤，未达条件不生效。提供低血输出窗口，避免以单纯增伤掩盖生存问题。',
             '- 其余混搭不因旧卡死结果统一增强。额外修复无区域配置时敌人状态字典初始化，保持新战术逻辑对旧遭遇的兼容；存档版本9迁移旧8奖励说明。', '',
             '## 受影响组合前后对照', '']
    for name in sorted(AFFECTED):
        a, b = before_groups[name], after_groups[name]
        lines.append(f'- **{describe(name)}**：胜场 {a["wins"]}/{a["samples"]} → {b["wins"]}/{b["samples"]}；平均回合 {a["mean_rounds"]} → {b["mean_rounds"]}；平均阵亡 {a["mean_dead"]} → {b["mean_dead"]}。')
    lines += ['', '## 队伍与混搭可用范围', '']
    for captain in CAPTAINS:
        for profile in PROFILE_NAMES:
            value = parties[f'{captain}/{profile}']
            lines.append(f'- {CAPTAIN_NAMES[captain]}／{PROFILE_NAMES[profile]}：{value["wins"]}/{value["samples"]}胜；50种非空配置中{value["winnable_loadouts"]}种至少获胜一次，28种两主题混搭中{value["winnable_pairs"]}种至少获胜一次。')
    lines += ['', '“至少一次获胜”只说明并非锁死在唯一配置，不代表每套配置都能在每区稳定通过。各配对胜率、回合和减员保存在JSON；生命仅按胜局统计，避免团长阵亡但其他人高生命的失利误排为高效率。显式天赋日志并不覆盖所有被动生效，不能用零播报推断天赋没有发挥。', '',
              '## 连续远征验证', '',
              f'- 同样18支队伍分别使用追猎＋秘法、血契＋生息两种2＋2混搭，合法预先成型4件，无额外遗物与购物，只领资源、实际消耗补给，经过真实连战、伤亡、首领与撤离：**{summary["routes"]["clears"]}/36通关**，共{summary["routes"]["battles"]}场战斗。每支队伍的两个混搭使用同一路线种子和地区。',
              '- 这是有明确训练和四遗物预算的预备队伍，非从零随机掉落的开荒通关率；不能替代普通玩家难度目标，也不意味着所有角色、全部遗物排列均已平衡。', '',
              '## 复跑与原始数据', '',
              '正式基线/复跑分片：artifacts/relic-mixes-controlled-{baseline,final}-{shen,wen,lu}.json；连续远征：artifacts/mixed-routes-final.json；完整分组汇总：artifacts/relic-mixes-summary.json。冻结源码压缩包包含代码、工具和空artifacts目录，解压后用Godot --path指定该目录即可复现。', '',
              '```sh',
              '.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/simulate_relic_mixes.gd -- --label=current --captain=shen',
              '# captain也可为wen或lu；不传captain则跑三位。mode=delta仅复跑受影响配置及抽查对照。',
              '.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/simulate_mixed_routes.gd -- --label=current',
              'python3 tools/summarize_relic_mixes.py', 'python3 tests/verify.py', '```', '',
              '汇总命令检查保存的controlled-baseline/controlled-final配对数据；当前工作区若继续开发，新跑结果以其自身源码hash为准。', '']
    (ROOT / 'docs' / 'relic-mixed-parties-report.md').write_text('\n'.join(lines))
    print(f'Validated {len(before)} baseline + {len(replay)} replay battles + 36 continuous routes')
    print('Affected:', {k: summary['combos'][k] for k in sorted(AFFECTED)})


if __name__ == '__main__':
    main()
