#!/usr/bin/env python3
"""Paired-seed comparison of three captains at four difficulties; no gameplay edits."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import math
from pathlib import Path
import zipfile

CAPTAINS = ['shen', 'wen', 'lu']
NAMES = {'shen': '沈烬', 'wen': '闻笙', 'lu': '陆衡'}
DIFFICULTIES = ['普通', '困难', '噩梦', '我想找死']


def wilson(k, n):
    z = 1.959963984540054
    p = k/n
    den = 1+z*z/n
    mid = (p+z*z/(2*n))/den
    half = z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/den
    return (0.0 if k == 0 else max(0.0, mid-half), 1.0 if k == n else min(1.0, mid+half))


def mcnemar_exact(b, c):
    n = b+c
    if n == 0:return 1.0
    return min(1.0, 2*sum(math.comb(n, k) for k in range(min(b, c)+1))/2**n)


def holm(values):
    order = sorted(range(len(values)), key=lambda i: values[i])
    result = [1.0]*len(values)
    last = 0.0
    for rank, i in enumerate(order):
        last = max(last, min(1.0, values[i]*(len(values)-rank)))
        result[i] = last
    return result


def summarize(root, snapshot):
    reports = {(c, d): json.loads((root/f'artifacts/captain-rates-main-{c}-{d}.json').read_text()) for c in CAPTAINS for d in range(4)}
    reference = reports[('shen', 0)]
    frozen_hashes = reference['source_hashes']
    for name, sha in frozen_hashes.items():assert hashlib.sha256((snapshot/'game'/name).read_bytes()).hexdigest() == sha
    for name, sha in reference['policy_hashes'].items():
        assert hashlib.sha256((snapshot/'tools'/name).read_bytes()).hexdigest() == sha
        assert hashlib.sha256((root/'tools'/name).read_bytes()).hexdigest() == sha
    for (c, d), report in reports.items():
        assert report['captain'] == c and report['difficulty'] == d
        assert report['runs'] == len(report['results']) == 500
        assert report['clears'] == sum(r['cleared'] for r in report['results'])
        assert [r['seed'] for r in report['results']] == list(range(2026102500, 2026103000))
        assert not report['changed_sources'] and report['source_hashes'] == frozen_hashes and report['policy_hashes'] == reference['policy_hashes']
        assert all(r['failure'] in ['', 'gameover', 'defeat'] for r in report['results'])
        for row in report['results']:
            assert row['captain'] == c and row['difficulty'] == d and row['initial_captain']['character_id'] == c
            assert row['initial_captain']['skill_ranks'] == {'strike': 1}
            assert all(not b['error'] for b in row['battles'])
    baseline_stats = {k: v for k, v in reference['results'][0]['initial_captain'].items() if k != 'character_id'}
    for report in reports.values():
        for row in report['results']:
            assert {k: v for k, v in row['initial_captain'].items() if k != 'character_id'} == baseline_stats
    for i in range(500):
        assert len({r['results'][i]['route_seed'] for r in reports.values()}) == 1
    # Rerun all Shen rows, then compare common fields to the historical 1,000-run cohort.
    historical_matches = []
    for d in range(4):
        old = json.loads((root/f'artifacts/difficulty-rates-main-{d}.json').read_text())['results'][:500]
        new = reports[('shen', d)]['results']
        matched = True
        for a, b in zip(old, new):
            matched &= all(a[k] == b[k] for k in ['seed', 'difficulty', 'cleared', 'failure', 'route_seed'])
            matched &= len(a['battles']) == len(b['battles'])
            if len(a['battles']) == len(b['battles']):
                matched &= all(all(bb[k] == v for k, v in ab.items()) for ab, bb in zip(a['battles'], b['battles']))
        historical_matches.append({'difficulty': d, 'matched_runs': 500 if matched else None, 'all_common_fields_match': matched})
    live = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'game').glob('*.gd')}
    scope_notes = {
        'campaign.gd': '战斗经验池提高与首件遗物商店优惠；本策略不训练、不购物，经验不自动提升面板或技能等级',
        'relics.gd': '奖励向已持有的第二主题倾斜；本策略不选择或携带遗物，主题计数始终为空，新增筛选不改变候选主题或随机抽取',
        'main.gd': '游戏界面改动；模拟不加载主场景或界面脚本',
    }
    drift = [{'file': name, 'snapshot_sha256': sha, 'live_sha256': live.get(name), 'scope': scope_notes.get(name, '未做静态范围判断，本次完整数据仅代表冻结快照')} for name, sha in frozen_hashes.items() if live.get(name) != sha]
    live_proof = json.loads((root/'artifacts/captain-rates-live-validation-2026-10-25.json').read_text())
    assert live_proof['live_source_hashes'] == live
    assert {(r['captain'], r['difficulty']) for r in live_proof['checks']} == set(reports)
    assert all(r['matched_runs'] == 5 for r in live_proof['checks'])
    for (c, d), report in reports.items():
        check = json.loads((root/f'artifacts/captain-rates-livecheck-{c}-{d}.json').read_text())
        assert check['results'] == report['results'][:5]
        assert check['source_hashes'] == live and not check['changed_sources']
    result = {
        'date': '2026-10-25', 'timezone': 'Asia/Shanghai', 'region': 'border',
        'runs_per_cell': 500, 'total_new_runs': 6000, 'seed_start': 2026102500, 'seed_end': 2026102999,
        'captains': CAPTAINS, 'difficulty_names': DIFFICULTIES,
        'source_hashes': frozen_hashes, 'policy_hashes': reference['policy_hashes'],
        'live_source_hashes': live, 'live_differences': drift, 'live_matching_runs': 60, 'initial_captain_stats': baseline_stats,
        'historical_shen_control': historical_matches,
        'gameplay_changed_by_this_study': False, 'rows': [], 'paired_comparisons': [],
    }
    proof = json.loads((root/'artifacts/captain-rates-validation-2026-10-25.json').read_text())
    assert {r['captain'] for r in proof['disk_comparisons']} == set(CAPTAINS)
    assert all(r['matched_runs'] == 5 for r in proof['disk_comparisons'])
    for c in CAPTAINS:
        disk = json.loads((snapshot/f'artifacts/captain-rates-diskcheck-{c}-0.json').read_text())
        pilot = json.loads((snapshot/f'artifacts/captain-rates-pilot-{c}-0.json').read_text())
        assert disk['results'] == pilot['results'] == reports[(c, 0)]['results'][:5]
    for (c, d), report in reports.items():
        rows = report['results']
        battles = [b for row in rows for b in row['battles']]
        low, high = wilson(report['clears'], 500)
        failure_threat = Counter(r['battles'][-1]['threat'] for r in rows if not r['cleared'])
        activations = sum(b['captain_talent_activations'][c] for b in battles)
        result['rows'].append({
            'captain': c, 'captain_name': NAMES[c], 'difficulty': d, 'difficulty_name': DIFFICULTIES[d],
            'runs': 500, 'clears': report['clears'], 'rate': report['clears']/500,
            'wilson_95_lower': low, 'wilson_95_upper': high,
            'failure_threat': dict(failure_threat),
            'boss_reached': sum(any(b['threat'] == 'boss' for b in r['battles']) for r in rows),
            'first_battle_failures': sum(not r['cleared'] and len(r['battles']) == 1 for r in rows),
            'battles': len(battles), 'battle_wins': sum(b['outcome'] == 'victory' for b in battles),
            'captain_talent_activations': activations,
            'expeditions_with_talent': sum(any(b['captain_talent_activations'][c] for b in r['battles']) for r in rows),
            'shen_followup_events': sum(b['shen_followups'] for b in battles),
        })
    for d in range(4):
        for a, b in itertools.combinations(CAPTAINS, 2):
            left = reports[(a, d)]['results'];right = reports[(b, d)]['results']
            states = Counter((x['cleared'], y['cleared']) for x, y in zip(left, right))
            only_a, only_b = states[(True, False)], states[(False, True)]
            result['paired_comparisons'].append({
                'difficulty': d, 'left': a, 'right': b,
                'both_clear': states[(True, True)], 'left_only_clear': only_a,
                'right_only_clear': only_b, 'both_fail': states[(False, False)],
                'difference_percentage_points': (only_a-only_b)*100/500,
                'p_exact': mcnemar_exact(only_a, only_b),
                'all_battle_measurements_match': all(x['battles'] == y['battles'] for x, y in zip(left, right)),
            })
    for pair, adjusted in zip(result['paired_comparisons'], holm([p['p_exact'] for p in result['paired_comparisons']])):
        pair['p_holm_12'] = adjusted
        pair['detectable_clear_rate_difference'] = adjusted < 0.05
    return result


def write_report(root, data):
    lines = ['# 三位主角 × 四档难度：首区通关率对照', '',
             '测试日期：2026 年 10 月 25 日（Asia/Shanghai）。本轮只测试，不修改主角、天赋、技能、敌人或难度数值，也不更新已确认的四档平衡参考值。', '',
             '## 固定条件', '',
             '- 每个主角×难度组合 500 局，共 12 个组合、6,000 局，全部重新运行，没有把历史样本计作本轮新跑。',
             '- 每组种子相同：2026102500—2026102999；逐局验证 12 个组合的路线种子一致。',
             '- 唯一主动更换的条件是主角身份：沈烬、闻笙、陆衡。四名同伴始终为阿绫、鸦、白芷、砾，盾卫留守，使用相同七件开局装备分配。',
             '- 三位主角初始面板一致：生命80、法力24、攻击22、防护2、速度12、射程1、经验0，只拥有1级破势。更换主角走实际 select_captain 接口，测试入口不要求解锁；游戏内解锁限制未修改。',
             '- 击败灰潮边境首领并成功撤离算通关。使用实际自动按钮策略，优先战斗、其次补给，只选资源奖励；生命低于70%或法力低于50%时用补给，保留死亡与消耗。',
             '- 不训练、购物、招募、选择遗物或预装成就奖励，沿用已确认基线的零成长策略。',
             '- 全部样本在同一冻结源码快照中运行，检查无无效动作、无战斗步数超限、无运行期源码变更；每位主角另跑5局验证跳过落盘与真实存档模式一致。', '',
             '## 首区通关率', '']
    for c in CAPTAINS:
        lines += [f'### {NAMES[c]}', '']
        for row in [r for r in data['rows'] if r['captain'] == c]:
            lines.append(f"- **{row['difficulty_name']}：{100*row['rate']:.1f}%（{row['clears']}/500）**；95% Wilson 区间 {100*row['wilson_95_lower']:.2f}%—{100*row['wilson_95_upper']:.2f}%。[逐局数据](../artifacts/captain-rates-main-{c}-{row['difficulty']}.json)")
        lines.append('')
    lines += ['![三位主角首区通关率对照](../artifacts/captain-rates-2026-10-25.png)', '',
              '## 逐种子比较与平衡判断', '',
              '比较同一难度、同一随机种子下是否通关，用精确 McNemar 双侧检验；对四档×三对主角共12次比较做 Holm 校正，校正后 p<0.05 记为可检出差异。未检出差异不等于证明严格平衡。', '']
    significant = [p for p in data['paired_comparisons'] if p['detectable_clear_rate_difference']]
    if not significant:
        lines += ['12组配对比较经校正后均未检出显著通关率差异；当前固定首区开局下，尚无足够统计证据判定某位主角显著更强。这不是等效性证明，也不覆盖成长后的平衡。', '']
    else:
        lines += [f'12组配对比较中，{len(significant)}组在校正后仍可检出通关率差异，具体方向与幅度见下文。', '']
    same_wen_lu = all(p['all_battle_measurements_match'] for p in data['paired_comparisons'] if p['left']=='wen' and p['right']=='lu')
    if same_wen_lu:
        lines += ['闻笙与陆衡在四档共2,000组同种子对照中，逐场战斗的所有测量字段一致；结合下文两人天赋未触发的记录，应将其理解为此开局条件下表现一致。', '']
    for d in range(4):
        lines += [f'### {DIFFICULTIES[d]}', '']
        group = [r for r in data['rows'] if r['difficulty'] == d]
        spread = 100*(max(r['rate'] for r in group)-min(r['rate'] for r in group))
        lines += [f'三位主角最大实测差距为 {spread:.1f} 个百分点。', '']
        for pair in [p for p in data['paired_comparisons'] if p['difficulty'] == d]:
            status = '可检出差异' if pair['detectable_clear_rate_difference'] else '未检出差异'
            lines.append(f"- {NAMES[pair['left']]}对{NAMES[pair['right']]}：差值 {pair['difference_percentage_points']:+.1f} 个百分点；仅前者通关 {pair['left_only_clear']} 局、仅后者通关 {pair['right_only_clear']} 局；Holm校正p={pair['p_holm_12']:.4g}，{status}。")
        if all(r['clears'] == 0 for r in group):
            lines += ['', '本档三人均为零胜，存在地板效应，不能据此可靠排出主角强弱；0/500的95% Wilson上限约0.76%，不代表真实概率绝对为零。']
        lines.append('')
    lines += ['## 天赋是否被实际用到', '']
    for c in CAPTAINS:
        rows = [r for r in data['rows'] if r['captain'] == c]
        lines.append(f"- **{NAMES[c]}**：四档共2,000局中，{sum(r['expeditions_with_talent'] for r in rows)}局记录到自身天赋触发，合计{sum(r['captain_talent_activations'] for r in rows)}次；沈烬号令后续命中事件{sum(r['shen_followup_events'] for r in rows)}次。")
    lines += ['', '沈烬可用初始破势触发号令；闻笙需要振奋或军心回响恢复同伴，陆衡需要同次行动施放两个来源职业不同的主动技能。本测试三人都只有1级破势，不能触发后两位的天赋；必须结合实测触发数解读。', '',
              '此结论针对首区零成长开局，不代表训练后、跨职业技能组合或专属遗物成型后的整体平衡。即便闻笙和陆衡数据一致，也不代表两人的完整培养路线相同；同样不能仅凭沈烬触发次数较多就推定其所有培养阶段必然更强。', '',
              '## 失败阶段', '']
    for c in CAPTAINS:
        for row in [r for r in data['rows'] if r['captain'] == c]:
            counts = row['failure_threat']
            lines.append(f"- {row['captain_name']}／{row['difficulty_name']}：普通遭遇失败{counts.get('normal',0)}局、精英失败{counts.get('elite',0)}局、首领失败{counts.get('boss',0)}局；到达首领{row['boss_reached']}局。")
    lines += ['', '## 与既有基线及版本的关系', '',
              '既有的40%、12.5%、2%、0%是已确认的沈烬首区参考值，不要求每位主角或每次小样本精确命中。本轮每组500局，历史每档1,000局，不能将两个不同样本量的百分比差异直接当成数值回归。', '']
    for item in data['historical_shen_control']:
        lines.append(f"- 沈烬／{DIFFICULTIES[item['difficulty']]}：与历史同一组前500局的逐局、逐战公共字段{'完全一致' if item['all_common_fields_match'] else '存在差异，不能直接复用历史基线判断'}。")
    if data['live_differences']:
        lines += ['', '运行结束时工作区与冻结快照存在以下差异。本轮精确通关率对应归档的冻结源码，不混合版本。', '']
        lines.extend(f"- `{item['file']}`：{item['scope']}；快照 {item['snapshot_sha256'][:12]}，当前 {item['live_sha256'][:12]}。" for item in data['live_differences'])
        lines += ['', '另在当前工作区对12个组合各重跑前5局，共60局逐局逐战字段与冻结快照完全一致。以上差异不作用于本次固定策略，但不能据此推断它们对正常培养、购物或遗物玩法没有影响。']
    else:
        lines += ['', '运行结束时，工作区游戏源码与开测冻结快照一致。']
    lines += ['', '## 复现资料', '',
              '- [结构化汇总、逐种子比较与天赋计数](../artifacts/captain-rates-summary-2026-10-25.json)。',
              '- [冻结源码与验证记录](../artifacts/captain-rates-source-2026-10-25.zip)。',
              '- 逐局报告共12份，命名为 `artifacts/captain-rates-main-{shen|wen|lu}-{0|1|2|3}.json`。',
              '- 运行器：`tools/simulate_captain_rates.gd`；汇总：`tools/summarize_captain_rates.py`。',
              '- [已确认的四档难度平衡基线](difficulty-balance-baseline-2026-10-25.md)。', '']
    (root/'docs/captain-balance-report-2026-10-25.md').write_text('\n'.join(lines))


def plot(root, data):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.font_manager import FontProperties
    font = FontProperties(fname='/System/Library/Fonts/STHeiti Medium.ttc')
    plt.rcParams['axes.unicode_minus'] = False
    fig, axes = plt.subplots(2, 2, figsize=(12, 7.5))
    for d, ax in enumerate(axes.flat):
        rows = sorted([r for r in data['rows'] if r['difficulty'] == d], key=lambda r: CAPTAINS.index(r['captain']))
        rates = [100*r['rate'] for r in rows]
        errors = [[100*(r['rate']-r['wilson_95_lower']) for r in rows], [100*(r['wilson_95_upper']-r['rate']) for r in rows]]
        ax.errorbar(rates, [0,1,2], xerr=errors, fmt='o', color='#206a8a', capsize=5, linewidth=2, label='实测与95%区间', zorder=3)
        ax.axvline([40,12.5,2,0][d], color='#8a8f92', linestyle='--', linewidth=1, label='既定首区参考值')
        for i, row in enumerate(rows):ax.annotate(f"{100*row['rate']:.1f}% ({row['clears']}/500)", (rates[i],i), xytext=(7,-18), textcoords='offset points', fontsize=10, color='#206a8a')
        limits = [55,25,7,2]
        xmax = max(limits[d], max(r['wilson_95_upper']*100 for r in rows)*1.2)
        ax.set_xlim(-0.5,xmax);ax.set_ylim(2.55,-0.65)
        ax.set_xticks([tick for tick in ax.get_xticks() if 0<=tick<=xmax])
        ax.set_yticks([0,1,2], [r['captain_name'] for r in rows], fontproperties=font)
        ax.set_title(DIFFICULTIES[d], fontproperties=font, fontsize=13, loc='left', pad=10)
        ax.set_xlabel('首区通关率（%，各图横轴范围不同）', fontproperties=font, fontsize=10)
        ax.grid(axis='x', color='#e3e7e9', linewidth=0.7);ax.set_axisbelow(True)
        for spine in ['top','right','left']:ax.spines[spine].set_visible(False)
        ax.spines['bottom'].set_color('#b5bfc3')
    handles, labels = axes.flat[0].get_legend_handles_labels()
    fig.legend(handles, labels, prop=font, loc='upper right', bbox_to_anchor=(0.98,0.98), ncol=2, frameon=False)
    fig.suptitle('三位主角：四档难度首区通关率', fontproperties=font, fontsize=17, x=0.07, ha='left')
    fig.text(0.07,0.018,'来源：游戏实际自动战斗；2026-10-25；每组500局，共6,000局；同种子、同伴与装备；零成长、无成就；本轮不调数值。',fontproperties=font,fontsize=9,color='#53626c')
    fig.tight_layout(rect=(0,0.06,1,0.91),h_pad=2.4,w_pad=3)
    fig.savefig(root/'artifacts/captain-rates-2026-10-25.png',dpi=170)
    fig.savefig(root/'artifacts/captain-rates-2026-10-25.svg')
    plt.close(fig)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument('--snapshot',type=Path,required=True)
    parser.add_argument('--no-plot',action='store_true')
    args=parser.parse_args();root=args.root.resolve();snapshot=args.snapshot.resolve()
    data=summarize(root,snapshot)
    (root/'artifacts/captain-rates-summary-2026-10-25.json').write_text(json.dumps(data,ensure_ascii=False,indent=2))
    if not args.no_plot:plot(root,data)
    write_report(root,data)
    with zipfile.ZipFile(root/'artifacts/captain-rates-source-2026-10-25.zip','w',zipfile.ZIP_DEFLATED) as archive:
        for name in data['source_hashes']:archive.write(snapshot/'game'/name,'game/'+name)
        for name in data['policy_hashes']:archive.write(snapshot/'tools'/name,'tools/'+name)
        archive.write(Path(__file__),'tools/summarize_captain_rates.py')
        archive.write(snapshot/'project.godot','project.godot')
        archive.writestr('artifacts/','')
        archive.write(root/'artifacts/captain-rates-validation-2026-10-25.json','validation.json')
        archive.write(root/'artifacts/captain-rates-live-validation-2026-10-25.json','live-validation.json')
        for item in data['live_differences']:archive.write(root/'game'/item['file'],'live/game/'+item['file'])
        for c in CAPTAINS:
            for d in range(4):archive.write(root/f'artifacts/captain-rates-livecheck-{c}-{d}.json',f'validation/live-{c}-{d}.json')
        for c in CAPTAINS:
            for label in ['pilot','diskcheck']:
                archive.write(snapshot/f'artifacts/captain-rates-{label}-{c}-0.json',f'validation/{label}-{c}.json')
        archive.writestr('manifest.json',json.dumps(data,ensure_ascii=False,indent=2))
    for row in data['rows']:print(f"{row['captain_name']} / {row['difficulty_name']}: {row['clears']}/500, talent={row['captain_talent_activations']}")
    for pair in data['paired_comparisons']:print('PAIR',pair)
    print('CAPTAIN_SUMMARY_VERIFIED: 6000 paired fresh runs; sources, controls, real-save parity and reports checked.')


if __name__=='__main__':main()
