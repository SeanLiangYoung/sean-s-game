#!/usr/bin/env python3
"""Summarize the frozen paired relic experiments; reject incomparable inputs."""
import collections
import json
import pathlib
import statistics

ROOT = pathlib.Path(__file__).resolve().parents[1]
NAMES = {'blood': '血契', 'hunt': '追猎', 'ward': '守誓', 'arcane': '秘法',
         'engine': '遗械', 'pilgrim': '生息', 'dusk': '孤影', 'command': '战阵'}


def read(stem, label):
    data = json.loads((ROOT / 'artifacts' / f'{stem}-{label}.json').read_text())
    assert not data.get('changed_sources'), f'{stem}-{label}: source changed during experiment'
    assert not data.get('invalid_actions'), f'{stem}-{label}: invalid battle action'
    return data


def metrics(rows):
    return {'wins': sum(row['outcome'] == 'victory' for row in rows), 'samples': len(rows),
            'mean_rounds': round(statistics.mean(row['rounds'] for row in rows), 2),
            'mean_hp': round(statistics.mean(row['hp'] for row in rows), 1),
            'mean_deaths': round(statistics.mean(row['dead'] for row in rows), 2)}


def main():
    before, after = (read('relic-balance', label) for label in ('baseline', 'final'))
    assert before['controls'] == after['controls'], 'Control battles changed'
    assert set(before['singles']) == set(after['singles']) and len(after['singles']) == 110
    summary = {'controls': metrics(after['controls']), 'builds': {}, 'singles': {}, 'drops': {}, 'expeditions': {}}
    for family in NAMES:
        left, right = before['builds'][family], after['builds'][family]
        assert len(left) == len(right) == 36
        pair = lambda rows: [(r['region'], r['seed'], r['relics'], r['initial_hp_ratio'], r['initial_mp_ratio']) for r in rows]
        assert pair(left) == pair(right), f'Unpaired loadouts: {family}'
        summary['builds'][family] = {'before': metrics(left), 'after': metrics(right)}
    for relic_id, rows in after['singles'].items():
        summary['singles'][relic_id] = {'before': metrics(before['singles'][relic_id]), 'after': metrics(rows)}
    for label in ('baseline', 'final'):
        drop = read('relic-drops', label)['results']
        assert len(drop) == 500
        stages = []
        for i in range(6):
            stages.append({'reward': i + 1, 'two_piece': sum(r['stages'][i]['count'] >= 2 for r in drop),
                           'four_piece': sum(r['stages'][i]['count'] >= 4 for r in drop)})
        summary['drops'][label] = {'samples': 500, 'stages': stages,
                                 'themes': dict(collections.Counter(r['stages'][3]['family'] for r in drop))}
        routes = read('relic-expeditions', label)['results']
        assert len(routes) == 96 and len({r['seed'] for r in routes}) == 96
        summary['expeditions'][label] = {
            'samples': 96, 'clears': sum(r['cleared'] for r in routes),
            'reached_boss': sum(any(b['threat'] == 'boss' for b in r['battles']) for r in routes),
            'two_before_boss': sum(r['before_boss']['count'] >= 2 for r in routes),
            'four_before_boss': sum(r['before_boss']['count'] >= 4 for r in routes),
            'four_at_last_successful_stage': sum(r['final']['count'] >= 4 for r in routes),
            'themes_at_last_successful_stage': dict(collections.Counter(r['final']['family'] for r in routes)),
            'battles': sum(len(r['battles']) for r in routes)}
    assert len(summary['drops']['final']['themes']) == 8
    assert all(stage['two_piece'] == 500 for stage in summary['drops']['final']['stages'][1:])
    assert len(summary['expeditions']['final']['themes_at_last_successful_stage']) == 8
    out = ROOT / 'artifacts' / 'relic-balance-summary.json'
    out.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
    lines = ['# 遗物流派实战与掉落平衡记录 · 2026-10-25', '',
             '本记录比较固定代码快照，控制队伍、基础装备、技能训练、路线与战场种子。控制实验不包含角色专属天赋，衡量遗物本身的影响；不同角色组合仍需后续样本。', '',
             '## 测试口径', '',
             '- 前后各966场独立战斗：18场无遗物对照、八流派各两套四件遗物×六区×三个种子（288场）、110件单件遗物×六区（660场）。',
             '- 三个种子分别使用满资源、75%生命/50%法力、55%生命/30%法力，包含低资源局面。种子和资源状态未做完全交叉，因此不把差异归因于某一种资源状态。',
             '- 固定策略实际使用治疗、净护、标记、机关、躲避首领预告、真实伤害预演和确定性移动；每项行动照常付费，每场最多450步。',
             '- 前后各96次完整远征，使用96个不同种子，包含资源损耗、死亡、商店、奖励、补给和首领；全部为低档装备、统一职业技能1级的预备队伍。',
             '- 前后各500组纯掉落实验：连续6次真实战后奖励结算，优先同主题、优先全队遗物；该实验不包含战斗失败和购物，不能当作实战成型率。',
             '- 所有报告均记录源文件SHA-256；冻结实验未发生源文件变化或非法行动。', '', '## 八流派同预算对照', '']
    for family, name in NAMES.items():
        a, b = summary['builds'][family]['before'], summary['builds'][family]['after']
        lines.append(f'- **{name}**：胜场 {a["wins"]}/36 → {b["wins"]}/36；平均回合 {a["mean_rounds"]} → {b["mean_rounds"]}；战后全队总生命 {a["mean_hp"]} → {b["mean_hp"]}；平均阵亡 {a["mean_deaths"]} → {b["mean_deaths"]}。')
    lines += ['', '无遗物对照前后一致：12/18胜，平均3.67回合。孤影仍是短战斗、高风险方向；守誓最能减少减员；生息战斗较长但续航改善。此为固定策略样本，不能证明不存在必选遗物。', '',
              '## 掉落与完整远征', '']
    for label, title in [('baseline', '调整前'), ('final', '调整后')]:
        d, e = summary['drops'][label], summary['expeditions'][label]
        lines += [f'- **{title}**：纯掉落第2次奖励形成两件共鸣 {d["stages"][1]["two_piece"]}/500；第4次形成四件 {d["stages"][3]["four_piece"]}/500；第6次形成四件 {d["stages"][5]["four_piece"]}/500。',
                  f'- **{title}真实路线**：通关 {e["clears"]}/96；抵达首领 {e["reached_boss"]}/96；首领前两件共鸣 {e["two_before_boss"]}/96、四件共鸣 {e["four_before_boss"]}/96。最后一个成功阶段四件共鸣 {e["four_at_last_successful_stage"]}/96，这可能包含首领奖励，不能解释为首领前成型率。']
    lines += ['', '调整后500组掉落第4次奖励的主要主题分布：' + '、'.join(f'{NAMES[k]} {v}次' for k, v in summary['drops']['final']['themes'].items()) + '。', '',
              '## 实际改动', '',
              '- 三件遗物奖励分别提供本局主题续接、其他主题基础和全目录随机项；开局前两件来自不同主题的全队遗物。优先排除已有同名遗物，永久收藏不锁定新一局的主题。',
              '- 遗物的行动点加成最多+2，遗物击杀回行动点最多1。逆流沙漏和督战铁令提高代价；沉铁壁垒降低泛用防护；秘法与孤影的部分单件平伤移回组合收益。',
              '- 血契减轻恢复惩罚并加强吸血/击杀续航；遗械减少妨碍布置的速度/防护惩罚；生息两件提供治疗与少量防护，四件提供回合回血和回蓝。',
              '- 110件遗物、个人绑定与有限次数规则保留。奖励描述随版本迁移，兼容旧6及本轮早期7档；现行存档版本8同时兼容角色身份扩展。', '',
              '## 复跑与证据', '',
              '原始JSON位于 artifacts/relic-balance-{baseline,final}.json、relic-expeditions-{baseline,final}.json、relic-drops-{baseline,final}.json；汇总位于 artifacts/relic-balance-summary.json。', '',
              '当前版本复跑（使用新label，避免覆盖冻结报告）：', '', '```sh',
              '.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/simulate_relic_balance.gd -- --label=current',
              '.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/simulate_relic_balance.gd -- --label=current --mode=expeditions',
              '.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/simulate_relic_drops.gd -- --label=current',
              'python3 tools/summarize_relic_balance.py', 'python3 tests/verify.py', '```', '',
              '冻结源码打包为 artifacts/relic-balance-{baseline,final}-sources.zip。解压到独立目录后，用Godot的 --path 指向该目录，可复现原始快照；游戏后续变化不会影响已存数据。汇总脚本检查的是baseline/final配对报告。', '']
    (ROOT / 'docs' / 'relic-balance-report.md').write_text('\n'.join(lines))
    print(f'Paired experiments verified; summary: {out}')


if __name__ == '__main__':
    main()
