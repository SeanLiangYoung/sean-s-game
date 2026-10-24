#!/usr/bin/env python3
"""Summarize the paired, fresh-start border difficulty study without changing gameplay."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import zipfile


def wilson(successes, total):
    z = 1.959963984540054
    p = successes / total
    denominator = 1 + z * z / total
    center = (p + z * z / (2 * total)) / denominator
    half = z * math.sqrt(p * (1 - p) / total + z * z / (4 * total * total)) / denominator
    return (0.0 if successes == 0 else max(0, center - half),
            1.0 if successes == total else min(1, center + half))


def summarize(root):
    reports = [json.loads((root / f'artifacts/difficulty-rates-main-{i}.json').read_text()) for i in range(4)]
    reference = reports[0]
    validation = json.loads((root/'artifacts/difficulty-rates-validation-2026-10-25.json').read_text())
    assert validation['pilot']['source_hashes'] == reference['source_hashes']
    assert validation['pilot']['results'] == validation['real_disk_save']['results']
    assert len(validation['pilot']['results']) == len(validation['historical_reference']['results']) == 10
    for pilot, old in zip(validation['pilot']['results'], validation['historical_reference']['results']):
        for key in ['seed', 'cleared', 'failure', 'battles']:assert pilot[key] == old[key]
    for report in reports:
        assert not report['changed_sources'], 'snapshot changed during simulation'
        assert report['source_hashes'] == reference['source_hashes'], 'different game snapshots'
        assert report['policy_hashes'] == reference['policy_hashes'], 'different simulation policies'
        assert report['runs'] == len(report['results']) == 1000
        assert [r['seed'] for r in report['results']] == list(range(2026102500, 2026103500)), 'unpaired or missing seeds'
        assert report['clears'] == sum(row['cleared'] for row in report['results'])
        assert all(row['failure'] in ['', 'gameover', 'defeat'] for row in report['results']), 'invalid simulation outcome'
    live_hashes = reference.get('live_source_hashes', reference['source_hashes'])
    for subdir, hashes in [('game', live_hashes), ('tools', reference['policy_hashes'])]:
        for filename, expected in hashes.items():
            actual = hashlib.sha256((root / subdir / filename).read_bytes()).hexdigest()
            assert actual == expected, f'live source no longer matches snapshot: {subdir}/{filename}'
    live_validation_path = root/'artifacts/difficulty-rates-live-validation-2026-10-25.json'
    live_validation = json.loads(live_validation_path.read_text())
    assert live_validation['live_source_hashes'] == live_hashes
    for report in reports:
        live = json.loads((root/f"artifacts/difficulty-rates-livecheck-{report['difficulty']}.json").read_text())
        assert live['source_hashes'] == live_hashes
        assert live['results'] == report['results'][:10]
    summary = {
        'date': '2026-10-25', 'timezone': 'Asia/Shanghai', 'region': 'border',
        'seed_start': 2026102500, 'seed_end': 2026103499,
        'policy': reference['policy'], 'source_hashes': reference['source_hashes'],
        'policy_hashes': reference['policy_hashes'], 'live_source_hashes': live_hashes,
        'source_scope_review': reference.get('source_scope_review', []), 'gameplay_changed_by_this_study': False, 'real_save_and_reference_parity_runs': 10,
        'same_route_seed_in_all_difficulties': all(len({r['results'][i]['route_seed'] for r in reports}) == 1 for i in range(1000)),
        'rows': [], 'paired_transitions': [],
    }
    assert summary['same_route_seed_in_all_difficulties']
    for report in reports:
        results = report['results']
        failures = [row for row in results if not row['cleared']]
        failure_threat = Counter(row['battles'][-1]['threat'] for row in failures)
        failure_depth = Counter(str(row['battles'][-1]['depth']) for row in failures)
        battles = [battle for row in results for battle in row['battles']]
        boss_reached = sum(any(b['threat'] == 'boss' for b in row['battles']) for row in results)
        boss_won = sum(any(b['threat'] == 'boss' and b['outcome'] == 'victory' for b in row['battles']) for row in results)
        lower, upper = wilson(report['clears'], report['runs'])
        target = report['target_rate']
        estimate = report['clears'] / report['runs']
        summary['rows'].append({
            'difficulty': report['difficulty'], 'name': report['difficulty_name'],
            'runs': report['runs'], 'clears': report['clears'], 'rate': estimate,
            'target': target, 'difference_percentage_points': 100 * (estimate - target),
            'wilson_95_lower': lower, 'wilson_95_upper': upper,
            'target_inside_interval': lower <= target <= upper,
            'assessment': '接近目标，样本尚不能区分' if lower <= target <= upper else ('低于目标' if estimate < target else '高于目标'),
            'failure_threat': dict(failure_threat), 'failure_depth': dict(failure_depth),
            'boss_reached': boss_reached, 'boss_won': boss_won,
            'first_battle_failures': sum(len(row['battles']) == 1 for row in failures),
            'battles': len(battles), 'battle_wins': sum(b['outcome'] == 'victory' for b in battles),
            'mean_battle_rounds': sum(b['rounds'] for b in battles) / len(battles),
            'invalid_actions_or_limits': sum(bool(b['error']) for b in battles),
        })
    for before, after in zip(reports, reports[1:]):
        pairs = Counter((a['cleared'], b['cleared']) for a, b in zip(before['results'], after['results']))
        summary['paired_transitions'].append({
            'from': before['difficulty_name'], 'to': after['difficulty_name'],
            'both_clear': pairs[(True, True)], 'only_lower_clear': pairs[(True, False)],
            'only_higher_clear': pairs[(False, True)], 'both_fail': pairs[(False, False)],
        })
    return summary


def write_report(root, data, plot):
    lines = [
        '# 四档难度首区通关率实测', '',
        '测试日期：2026 年 10 月 25 日（Asia/Shanghai）。本轮只测量，不修改游戏难度或战斗数值。', '',
        '## 口径与固定条件', '',
        '- 一局从零开始；击败灰潮边境首领并成功撤离，才记为通关。不是通关全部六个区域。',
        '- 每档 1,000 局，共 4,000 局；四档使用完全相同的种子 2026102500—2026103499，并验证每局路线种子一致。',
        '- 固定沈烬、阿绫、鸦、白芷、砾五人；按既有普通 50% 校准策略分配七件开局装备，板甲不穿。死亡与血蓝消耗保留，不复活、不重试。',
        '- 优先战斗，其次免费补给；只选资源奖励；任意存活队员生命不足 70% 或法力不足 50% 时使用补给。',
        '- 战斗使用游戏实际的 Rules.auto_action 自动按钮策略；不额外训练、购物、招募或选择遗物，不预装成就奖励。',
        '- 在隔离源码快照中运行；每 100 局为一批，各批源码与策略哈希一致，并在汇总时与当前项目源码再次核对；版本差异见下文。',
        '- 内存运行仅跳过存档落盘与成就文件读取，战斗、路线、奖励、补给、死亡和撤离调用实际游戏接口；额外 10 局与真实落盘模式逐局比较，结果、每场战斗、剩余生命、补给和路线种子完全一致；同一批结果也与原始普通难度模拟器逐战一致。', '',
        '## 实测结果', '',
    ]
    for row in data['rows']:
        lines.append(f"- **{row['name']}**：{row['clears']:,}/{row['runs']:,}，**{100*row['rate']:.1f}%**；目标 {100*row['target']:g}%；差值 {row['difference_percentage_points']:+.1f} 个百分点；95% Wilson 区间 {100*row['wilson_95_lower']:.2f}%—{100*row['wilson_95_upper']:.2f}%；{row['assessment']}。")
    if plot:
        lines += ['', '![首区通关率与目标对照](../artifacts/difficulty-rates-2026-10-25.png)']
    lines += ['', '## 失败集中在哪里', '']
    for row in data['rows']:
        counts = row['failure_threat']
        lines.append(f"- **{row['name']}**：普通遭遇失败 {counts.get('normal', 0)} 局、精英失败 {counts.get('elite', 0)} 局、首领失败 {counts.get('boss', 0)} 局；到达首领 {row['boss_reached']} 局，其中击败首领 {row['boss_won']} 局；首次战斗即失败 {row['first_battle_failures']} 局。")
    lines += ['', '## 梯度判断', '']
    rates = [row['rate'] for row in data['rows']]
    if all(a > b for a, b in zip(rates, rates[1:])):
        lines.append('四档实测通关率严格递减，变难方向成立。')
    else:
        lines.append('四档实测通关率未严格递减，需要结合区间和逐局数据解读。')
    if all(row['assessment'] == '低于目标' for row in data['rows']):
        lines += ['', '四档目标均高于各自的 95% Wilson 区间，当前固定策略下的整体难度偏高。']
    if rates[1] > 0:
        lines += ['', f"困难→噩梦：目标希望保留 40% 的通关率（10%/25%）；实测只保留 {100*rates[2]/rates[1]:.1f}%，这一档的下降明显更陡。"]
    if data['rows'][3]['clears'] == 0:
        lines += ['', f"最高难度在 1,000 局中没有通关，95% Wilson 上限为 {100*data['rows'][3]['wilson_95_upper']:.2f}%，低于 1% 目标；这不表示真实通关率绝对为零。"]
    lines += ['', '本轮没有据此调整任何游戏数值。']
    lines += ['', '## 版本检查', '']
    if data['source_scope_review']:
        lines.append('运行期间，工作区另有以下改动；本轮 4,000 局全部来自同一冻结快照，没有混合版本，也没有在本轮改动这些文件。')
        lines.append('')
        for item in data['source_scope_review']:lines.append(f"- `{item['file']}`：{item['scope']}。")
        lines += ['', '代码差异复核显示，上述改动不作用于本次“灰潮边境、无遗物”的测试条件；另外在当前工作区对每档前 10 局重跑，共 40 局逐局逐战数据与冻结快照完全一致。完整抽样率仍对应归档的冻结源码。', '']
    else:
        lines.append('当前工作区源码与开测快照完全一致。')
    lines += ['', '## 解读范围', '',
              '这些结果衡量当前版本、固定开局与固定自动策略的首区通关概率，不等同于所有真人玩家、主角、遗物构筑和养成策略的概率。高难度实际解锁后的成就属性、后续技能训练与购物可能改变结果；本次为了单独比较敌人强度，没有混入这些收益。', '',
              '区间反映有限种子样本的不确定性。0/1,000 只表示本次没有观察到通关，不表示真实概率绝对为零。目标落在区间外时，本样本不支持该目标已经达成；“接近目标”也不是证明真实概率恰好等于目标。', '',
              '固定种子下，更高难度偶尔通关而低难度失败并不自动意味着数值倒挂：敌人生命变化可能改变自动策略的目标选择和行动顺序。梯度评价以整体通关率为主。', '',
              '## 可复现资料', '',
              '- 汇总与失败分布：`artifacts/difficulty-rates-summary-2026-10-25.json`。',
              '- 全部逐局、逐战数据：`artifacts/difficulty-rates-main-0.json` 至 `artifacts/difficulty-rates-main-3.json`。',
              '- 运行源码与策略快照：`artifacts/difficulty-rates-source-2026-10-25.zip`。',
              '- 模拟：`tools/simulate_difficulty_rates.gd`；汇总：`tools/summarize_difficulty_rates.py`。', '',
              '单档重跑示例（需先建好 artifacts 目录；精确复现应使用归档源码，当前源码另有变更时应建立新的验证记录）：', '', '```sh',
              '.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/simulate_difficulty_rates.gd -- --difficulty=0 --count=1000 --label=main',
              '```', '',
              '四档的 `--difficulty` 分别为 0、1、2、3。默认种子从 2026102500 起；支持 `--count` 和 `--seed-start` 分批运行。汇总校验要求每档恰好 1,000 局且种子完整不重复。', '']
    (root / 'docs/difficulty-rates-report-2026-10-25.md').write_text('\n'.join(lines))


def plot_report(root, data):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.font_manager import FontProperties
    font = FontProperties(fname='/System/Library/Fonts/STHeiti Medium.ttc')
    plt.rcParams.update({'axes.unicode_minus': False, 'font.size': 11})
    fig, axes = plt.subplots(1, 2, figsize=(13, 5.3), gridspec_kw={'width_ratios': [1.6, 1]})
    fig.patch.set_facecolor('white')
    for ax, rows, xmax, title in [(axes[0], data['rows'], 60, '全部四档'), (axes[1], data['rows'][2:], 15, '高难度放大')]:
        y = list(range(len(rows)))
        rates = [100*r['rate'] for r in rows]
        lower = [100*(r['rate']-r['wilson_95_lower']) for r in rows]
        upper = [100*(r['wilson_95_upper']-r['rate']) for r in rows]
        ax.errorbar(rates, y, xerr=[lower, upper], fmt='o', color='#206a8a', capsize=5, linewidth=2, label='实测与95%区间', zorder=3)
        ax.scatter([100*r['target'] for r in rows], y, marker='D', s=45, color='#ad7726', label='目标', zorder=4)
        for i, r in enumerate(rows):
            ax.annotate(f"{100*r['rate']:.1f}% ({r['clears']}/1000)", (rates[i], i), xytext=(6, -19), textcoords='offset points', color='#206a8a', fontsize=10)
        ax.set_yticks(y, [r['name'] for r in rows], fontproperties=font)
        ax.set_xlim(-0.5, xmax)
        ax.set_ylim(len(rows)-0.6, -0.6)
        ax.set_title(title, fontproperties=font, fontsize=13, loc='left', pad=15)
        ax.set_xlabel('首区通关率（%）', fontproperties=font)
        ax.set_ylabel('整体难度', fontproperties=font)
        ax.grid(axis='x', color='#e3e7e9', linewidth=0.7)
        ax.set_axisbelow(True)
        for spine in ['top', 'right', 'left']:ax.spines[spine].set_visible(False)
        ax.spines['bottom'].set_color('#b5bfc3')
    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(handles, labels, prop=font, loc='upper right', bbox_to_anchor=(0.97, 0.96), frameon=False, ncol=2)
    fig.suptitle('灰潮边境：实测通关率与目标对照', fontproperties=font, fontsize=17, x=0.06, ha='left')
    fig.text(0.06, 0.015, '来源：游戏实际自动战斗；2026-10-25；每档1,000局，同一组种子；固定沈烬开局，无成就加成，不调数值。', fontproperties=font, fontsize=10, color='#53626c')
    fig.tight_layout(rect=(0, 0.07, 1, 0.92), w_pad=3)
    fig.savefig(root/'artifacts/difficulty-rates-2026-10-25.png', dpi=170)
    fig.savefig(root/'artifacts/difficulty-rates-2026-10-25.svg')
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--no-plot', action='store_true')
    parser.add_argument('--snapshot', type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    data = summarize(root)
    (root/'artifacts/difficulty-rates-summary-2026-10-25.json').write_text(json.dumps(data, ensure_ascii=False, indent=2))
    if not args.no_plot:plot_report(root, data)
    write_report(root, data, not args.no_plot)
    with zipfile.ZipFile(root/'artifacts/difficulty-rates-source-2026-10-25.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        source_root = args.snapshot.resolve() if args.snapshot else root
        for name, expected in data['source_hashes'].items():
            path = source_root/'game'/name
            assert hashlib.sha256(path.read_bytes()).hexdigest() == expected
            archive.write(path, 'game/'+name)
        for name in data['policy_hashes']:archive.write(root/'tools'/name, 'tools/'+name)
        archive.write(Path(__file__), 'tools/summarize_difficulty_rates.py')
        archive.write(root/'artifacts/difficulty-rates-validation-2026-10-25.json', 'validation.json')
        archive.write(root/'artifacts/difficulty-rates-live-validation-2026-10-25.json', 'live-validation.json')
        for item in data['source_scope_review']:archive.write(root/'game'/item['file'], 'live/game/'+item['file'])
        archive.writestr('project.godot', 'config_version=5\n\n[application]\nconfig/name="DifficultyStudy"\n')
        archive.writestr('manifest.json', json.dumps(data, ensure_ascii=False, indent=2))
    print(json.dumps(data['rows'], ensure_ascii=False, indent=2))


if __name__ == '__main__':main()
