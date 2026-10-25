#!/usr/bin/env python3
"""Audit the identical-105XP captain experiment and summarize paired outcomes."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import re
from pathlib import Path
import zipfile
from summarize_captain_rates import wilson, mcnemar_exact, holm

CAPTAINS=['shen','wen','lu']
NAMES={'shen':'沈烬','wen':'闻笙','lu':'陆衡'}
DIFFICULTIES=['普通','困难','噩梦','我想找死']
KIT={'strike':2,'hero_heal':1,'mark':1}


def summarize(root,snapshot):
    reports={(c,d):json.loads((root/f'artifacts/trained-captain-rates-main-{c}-{d}.json').read_text()) for c in CAPTAINS for d in range(4)}
    reference=reports['shen',0]
    for name,sha in reference['source_hashes'].items():assert hashlib.sha256((snapshot/'game'/name).read_bytes()).hexdigest()==sha
    for name,sha in reference['policy_hashes'].items():
        assert hashlib.sha256((snapshot/'tools'/name).read_bytes()).hexdigest()==sha
    validation=json.loads((root/'artifacts/trained-captain-validation-2026-10-25.json').read_text())
    assert validation['budget']==105 and validation['skill_ranks']==KIT and validation['training_fixture_checks']==24
    assert validation['memory_disk_matches']=={'shen':10,'wen':10,'lu':10}
    initial={k:v for k,v in reference['results'][0]['initial_captain'].items() if k!='character_id'}
    ledger=reference['results'][0]['training']['ledger']
    for (c,d),report in reports.items():
        assert report['captain']==c and report['difficulty']==d and report['runs']==len(report['results'])==500
        assert report['source_hashes']==reference['source_hashes'] and report['policy_hashes']==reference['policy_hashes'] and not report['changed_sources']
        assert report['clears']==sum(row['cleared'] for row in report['results'])
        assert [row['seed'] for row in report['results']]==list(range(2026102500,2026103000))
        for row in report['results']:
            assert row['captain']==c and row['difficulty']==d and row['failure'] in ['','gameover','defeat']
            assert row['initial_captain']['character_id']==c and row['initial_captain']['skill_ranks']==KIT
            assert {k:v for k,v in row['initial_captain'].items() if k!='character_id'}==initial
            t=row['training']
            assert t['budget']==t['spent']==105 and t['remaining']==0 and t['error']=='' and t['ledger']==ledger
            assert all(not b['error'] for b in row['battles'])
        if d==0:
            pilot=json.loads((snapshot/f'artifacts/trained-captain-rates-pilot-{c}-0.json').read_text())
            disk=json.loads((snapshot/f'artifacts/trained-captain-rates-diskcheck-{c}-0.json').read_text())
            assert pilot['results']==disk['results']==report['results'][:10]
    for i in range(500):assert len({r['results'][i]['route_seed'] for r in reports.values()})==1
    live_policy={name:hashlib.sha256((root/'tools'/name).read_bytes()).hexdigest() for name in reference['policy_hashes']}
    policy_drift=[name for name,sha in reference['policy_hashes'].items() if live_policy[name]!=sha]
    assert set(policy_drift)<=set(['relic_mix_simulation.gd']), 'unreviewed study driver change'
    if policy_drift:
        assert 'var support_ai=false' in (root/'tools/relic_mix_simulation.gd').read_text()
        assert 'support_ai' not in (root/'tools/simulate_trained_captains.gd').read_text()
    live={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'game').glob('*.gd')}
    live_proof=json.loads((root/'artifacts/trained-captain-live-validation-2026-10-25.json').read_text())
    assert live_proof['live_source_hashes']==live and live_proof['matched_runs']==60
    assert {(x['captain'],x['difficulty']) for x in live_proof['checks']}==set(reports)
    for (c,d),report in reports.items():
        checked=json.loads((root/f'artifacts/trained-captain-rates-livecheck-{c}-{d}.json').read_text())
        assert checked['results']==report['results'][:5] and checked['source_hashes']==live and checked['policy_hashes']==live_policy and not checked['changed_sources']
    frozen_rules=(snapshot/'game/rules.gd').read_text();live_rules=(root/'game/rules.gd').read_text()
    def functions(source):
        matches=list(re.finditer(r'^func (\w+)\(',source,re.M))
        return {m.group(1):source[m.start():matches[i+1].start() if i+1<len(matches) else len(source)] for i,m in enumerate(matches)}
    old_functions=functions(frozen_rules);new_functions=functions(live_rules)
    changed_functions=sorted(name for name in old_functions.keys()|new_functions.keys() if old_functions.get(name)!=new_functions.get(name))
    same_header=frozen_rules.split('func ',1)[0]==live_rules.split('func ',1)[0]
    only_auto_changes=same_header and set(changed_functions)<=set(['auto_action','auto_support_action','auto_incoming_pressure','auto_support_cell_safe'])
    summary={'date':'2026-10-25','timezone':'Asia/Shanghai','region':'border','runs_per_cell':500,'total_runs':6000,
             'training_budget':105,'skill_ranks':KIT,'training_ledger':ledger,'initial_captain_stats':initial,
             'seed_start':2026102500,'seed_end':2026102999,'source_hashes':reference['source_hashes'],
             'policy_hashes':reference['policy_hashes'],'live_policy_hashes':live_policy,'live_policy_differences':policy_drift,'live_source_hashes':live,
             'live_differences':[name for name,sha in reference['source_hashes'].items() if live.get(name)!=sha],
             'rules_changed_functions':changed_functions,'rules_only_auto_changes':only_auto_changes,
             'gameplay_changed_by_this_study':False,'uses_game_auto_button_policy':False,'live_validation_matched_runs':60,
             'policy':'same support-aware relic_mix_simulation.step for every captain and ally; no identity-specific scripted decisions',
             'rows':[],'pairs':[]}
    for (c,d),report in reports.items():
        rows=report['results'];battles=[b for r in rows for b in r['battles']];low,high=wilson(report['clears'],500)
        summary['rows'].append({'captain':c,'captain_name':NAMES[c],'difficulty':d,'difficulty_name':DIFFICULTIES[d],
                                'runs':500,'clears':report['clears'],'rate':report['clears']/500,
                                'wilson_95_lower':low,'wilson_95_upper':high,
                                'failure_threat':dict(Counter(r['battles'][-1]['threat'] for r in rows if not r['cleared'])),
                                'boss_reached':sum(any(b['threat']=='boss' for b in r['battles']) for r in rows),
                                'battles':len(battles),'battle_wins':sum(b['outcome']=='victory' for b in battles),
                                'talent_activations':sum(b['captain_talent_activations'][c] for b in battles),
                                'expeditions_with_talent':sum(any(b['captain_talent_activations'][c] for b in r['battles']) for r in rows),
                                'shen_followups':sum(b['shen_followups'] for b in battles)})
    assert all(r['talent_activations']>0 for r in summary['rows']), 'a captain talent was never exercised in a study cell'
    for d in range(4):
        for a,b in itertools.combinations(CAPTAINS,2):
            counts=Counter((x['cleared'],y['cleared']) for x,y in zip(reports[a,d]['results'],reports[b,d]['results']))
            left,right=counts[True,False],counts[False,True]
            summary['pairs'].append({'difficulty':d,'left':a,'right':b,'left_only':left,'right_only':right,
                                     'both_clear':counts[True,True],'both_fail':counts[False,False],
                                     'difference_pp':(left-right)/5,'p_exact':mcnemar_exact(left,right)})
    for pair,adjusted in zip(summary['pairs'],holm([p['p_exact'] for p in summary['pairs']])):
        pair['p_holm_12']=adjusted;pair['detectable_difference']=adjusted<0.05
    return summary


def write_report(root,data):
    lines=['# 相同105经验培养后三位主角的首区平衡测试','',
           '测试日期：2026 年 10 月 25 日（Asia/Shanghai）。只在测试队伍中注入经验并学习技能，没有调整游戏数值、主角天赋、技能成本、敌人或游戏内自动战斗。原有四档平衡基线不变。','',
           '## 相同预算、相同技能包','',
           '三位主角每局都获得105点测试经验，通过真实 `Campaign.train_skill` 接口逐项扣费，实际花费均为105，初始剩余经验均为0。没有修改技能等级字段绕过费用或前置条件。','',
           '- 破势：原有1级升至2级，45经验。',
           '- 振奋：学习1级，30经验；前置破势2级已满足。',
           '- 猎物标记：跨职业学习1级，30经验；主角按现行规则可学习。','',
           '三人拥有完全相同的技能和面板，主动变化仅为主角身份。沈烬可用破势触发号令；闻笙可用振奋恢复同伴并触发护盾；陆衡可在4行动点内使用猎物标记（1点）＋破势（3点），支付真实法力后触发跨职业回蓝。','',
           '四位同伴始终为阿绫、鸦、白芷、砾，保持原始技能与经验，盾卫留守。装备沿用既有七件分配，没有额外武器、饰品、遗物或成就加成。后续战斗虽正常获得经验，但本测试不再训练，不将战后额外经验加入105预算。','',
           '## 共享测试策略与口径','',
           '- 每个主角×难度组合500局，共12组、6,000局，种子2026102500—2026102999逐局配对，验证12组路线种子一致。',
           '- 从零开始，击败灰潮边境首领并成功撤离才算通关；死亡与血蓝消耗保留，不复活、不重试。',
           '- 路线优先战斗，其次补给；只选资源奖励；生命低于70%或法力低于50%时用补给。不购物、不招募、不选择遗物。',
           '- 开测版本的游戏自动按钮只主动挑选伤害技能，不主动治疗或标记；直接沿用会让后两位天赋仍难以进入测试。',
           '- 本轮统一使用项目已有的 `relic_mix_simulation.step` 支持型模拟策略：按公开战况避开首领预告、治疗受伤队友、在合适行动预算下标记、再选择伤害及移动。所有主角与同伴共用同一规则，不按主角身份安排专属脚本，也不修改游戏内自动策略。',
           '- 因为策略与培养预算都不同，本轮结果不能与上次零成长、自动按钮策略的百分比直接相减来衡量培养收益，也不替代40%/12.5%/2%/0%的原基线。',
           '- 在同一冻结源码中运行，预算及天赋探针24项通过；三位主角各10局与真实存档落盘模式完全一致。','',
           '## 首区通关率','']
    for c in CAPTAINS:
        lines += [f'### {NAMES[c]}','']
        for r in [r for r in data['rows'] if r['captain']==c]:
            lines.append(f"- **{r['difficulty_name']}：{100*r['rate']:.1f}%（{r['clears']}/500）**；95% Wilson区间 {100*r['wilson_95_lower']:.2f}%—{100*r['wilson_95_upper']:.2f}%。[逐局数据](../artifacts/trained-captain-rates-main-{c}-{r['difficulty']}.json)")
        lines.append('')
    lines += ['![105经验共同技能包主角对照](../artifacts/trained-captain-rates-2026-10-25.png)','',
              '## 配对差异与平衡判断','',
              '同一难度内对同一种子的通关结果进行精确McNemar双侧检验，12组比较统一作Holm校正，校正后p<0.05记为可检出差异。未检出差异不等于证明严格等效。','']
    significant=[p for p in data['pairs'] if p['detectable_difference']]
    if significant:lines += [f'本轮{len(significant)}组配对在校正后仍可检出差异；需结合下面的百分点差距和方案范围判断，不能直接外推为主角所有培养路线的强弱。','']
    else:lines += ['本轮12组配对在校正后均未检出显著差异；当前105经验共同技能包下，尚无足够统计证据认定某位主角显著更强，也不构成所有培养阶段平衡的证明。','']
    for d in range(4):
        rows=[r for r in data['rows'] if r['difficulty']==d]
        spread=100*(max(r['rate'] for r in rows)-min(r['rate'] for r in rows))
        lines += [f'### {DIFFICULTIES[d]}','',f'最大实测差距：{spread:.1f}个百分点。','']
        for p in [p for p in data['pairs'] if p['difficulty']==d]:
            lines.append(f"- {NAMES[p['left']]}对{NAMES[p['right']]}：{p['difference_pp']:+.1f}个百分点；仅前者通关{p['left_only']}局，仅后者通关{p['right_only']}局；校正p={p['p_holm_12']:.4g}，{'可检出差异' if p['detectable_difference'] else '未检出差异'}。")
        if all(r['clears']==0 for r in rows):lines += ['','三人均零通关，存在地板效应，不能据此排出高难度强弱。0/500的95% Wilson上限约0.76%，不是绝对不可能通关。']
        lines.append('')
    lines += ['## 天赋实际触发','']
    for r in data['rows']:
        lines.append(f"- {r['captain_name']}／{r['difficulty_name']}：{r['expeditions_with_talent']}/500局出现自身天赋事件，合计{r['talent_activations']}次。")
    lines += ['','记录的是实际战斗日志中的天赋事件，不是仅凭已学技能推断；触发次数也不等于对胜率的直接贡献。沈烬的号令宣告与后续命中另有独立计数，避免把对已阵亡目标的宣告全部视为有效增伤。','',
              '## 失败阶段与首领到达率','']
    for r in data['rows']:
        f=r['failure_threat'];lines.append(f"- {r['captain_name']}／{r['difficulty_name']}：普通遭遇失败{f.get('normal',0)}局、精英失败{f.get('elite',0)}局、首领失败{f.get('boss',0)}局；到达首领{r['boss_reached']}/500局。")
    lines += ['','## 结论范围与源码','',
              '这是一套相同预算、相同技能包、相同策略的天赋对照，不是搜索每个主角的最优流派。它覆盖天赋开始进入实战的105经验阶段，不覆盖更高预算、多职业连招、遗物成型、其他队伍或真人手动操作。','',
              '全部6,000局无无效动作、无步数超限，训练扣费与前置条件逐局核验。精确结果对应归档的冻结源码。']
    if data['live_differences']:
        lines += ['', '运行结束时工作区与冻结源码有差异：'+', '.join('`'+x+'`' for x in data['live_differences'])+'。各组结果没有混合版本。']
        if data['live_differences']==['rules.gd'] and data['rules_only_auto_changes']:
            lines += ['', '差异复核：工作区为自动按钮新增了治疗与医者走位判断；本次共享模拟策略不调用这些新增的自动决策函数，使用的 auto_best_hit 与实际结算方法未在该差异中改变。']
        lines += ['', '另在当前工作区对12个组合各复跑前5局，共60局，逐局逐战字段及训练账本与冻结快照完全一致。完整6,000局仍以归档的冻结源码为准。']
    else:lines += ['', '运行结束时工作区游戏源码与冻结快照一致。']
    if data['live_policy_differences']:
        lines += ['', '模拟辅助库 relic_mix_simulation.gd 另有新增的 support_ai 开关及保护分支，默认值为 false。本驱动从未开启该开关，新增分支不进入本次执行路径；当前库的12组、共60局复核结果与冻结数据完全一致。冻结库与当前库分别归档，原始策略哈希没有改写。']
    lines += ['','## 资料','',
              '- [结构化汇总、训练账本与配对比较](../artifacts/trained-captain-rates-summary-2026-10-25.json)。',
              '- [冻结源码、测试探针与真实存档验证](../artifacts/trained-captain-rates-source-2026-10-25.zip)。',
              '- [上一次零成长对照](captain-balance-report-2026-10-25.md)与[已确认难度基线](difficulty-balance-baseline-2026-10-25.md)。',
              '- 运行器：`tools/simulate_trained_captains.gd`；预算方案：`tools/captain_training_plan.gd`；汇总：`tools/summarize_trained_captains.py`。','']
    (root/'docs/trained-captain-balance-report-2026-10-25.md').write_text('\n'.join(lines))


def plot(root,data):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.font_manager import FontProperties
    font=FontProperties(fname='/System/Library/Fonts/STHeiti Medium.ttc');plt.rcParams['axes.unicode_minus']=False
    fig,axes=plt.subplots(2,2,figsize=(12,7.5))
    for d,ax in enumerate(axes.flat):
        rows=[next(r for r in data['rows'] if r['captain']==c and r['difficulty']==d) for c in CAPTAINS]
        rates=[100*r['rate'] for r in rows]
        errors=[[100*(r['rate']-r['wilson_95_lower']) for r in rows],[100*(r['wilson_95_upper']-r['rate']) for r in rows]]
        ax.errorbar(rates,[0,1,2],xerr=errors,fmt='o',color='#206a8a',capsize=5,linewidth=2,label='实测与95%区间',zorder=3)
        for i,r in enumerate(rows):ax.annotate(f"{100*r['rate']:.1f}% ({r['clears']}/500)",(rates[i],i),xytext=(7,-18),textcoords='offset points',fontsize=10,color='#206a8a')
        xmax=max([55,35,10,2][d],max(r['wilson_95_upper']*100 for r in rows)*1.2)
        ax.set_xlim(-.5,xmax);ax.set_ylim(2.55,-.65);ax.set_xticks([t for t in ax.get_xticks() if 0<=t<=xmax])
        ax.set_yticks([0,1,2],[r['captain_name'] for r in rows],fontproperties=font)
        ax.set_title(DIFFICULTIES[d],fontproperties=font,fontsize=13,loc='left',pad=10)
        ax.set_xlabel('首区通关率（%，各图横轴范围不同）',fontproperties=font,fontsize=10)
        ax.grid(axis='x',color='#e3e7e9',linewidth=.7);ax.set_axisbelow(True)
        for edge in ['top','right','left']:ax.spines[edge].set_visible(False)
        ax.spines['bottom'].set_color('#b5bfc3')
    handles,labels=axes.flat[0].get_legend_handles_labels();fig.legend(handles,labels,prop=font,loc='upper right',bbox_to_anchor=(.98,.98),frameon=False)
    fig.suptitle('相同105经验培养：三位主角首区通关率',fontproperties=font,fontsize=17,x=.07,ha='left')
    fig.text(.07,.018,'来源：冻结游戏版本；2026-10-25；每组500局，共6,000局；破势2＋振奋1＋标记1；同支持型测试策略；本轮不调数值。',fontproperties=font,fontsize=9,color='#53626c')
    fig.tight_layout(rect=(0,.06,1,.91),h_pad=2.4,w_pad=3)
    fig.savefig(root/'artifacts/trained-captain-rates-2026-10-25.png',dpi=170);fig.savefig(root/'artifacts/trained-captain-rates-2026-10-25.svg');plt.close(fig)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);parser.add_argument('--snapshot',type=Path,required=True);parser.add_argument('--no-plot',action='store_true');args=parser.parse_args()
    root=args.root.resolve();snapshot=args.snapshot.resolve();data=summarize(root,snapshot)
    data['analysis_hashes']={name:hashlib.sha256((root/'tools'/name).read_bytes()).hexdigest() for name in ['summarize_trained_captains.py','summarize_captain_rates.py']}
    (root/'artifacts/trained-captain-rates-summary-2026-10-25.json').write_text(json.dumps(data,ensure_ascii=False,indent=2))
    if not args.no_plot:plot(root,data)
    write_report(root,data)
    with zipfile.ZipFile(root/'artifacts/trained-captain-rates-source-2026-10-25.zip','w',zipfile.ZIP_DEFLATED) as z:
        for name in data['source_hashes']:z.write(snapshot/'game'/name,'game/'+name)
        for name in data['policy_hashes']:z.write(snapshot/'tools'/name,'tools/'+name)
        for name in data['analysis_hashes']:z.write(root/'tools'/name,'tools/'+name)
        z.write(snapshot/'tests/captain_training_study.gd','tests/captain_training_study.gd');z.write(snapshot/'project.godot','project.godot');z.writestr('artifacts/','')
        z.write(root/'artifacts/trained-captain-validation-2026-10-25.json','validation.json')
        z.write(root/'artifacts/trained-captain-live-validation-2026-10-25.json','live-validation.json')
        for name in data['live_differences']:z.write(root/'game'/name,'live/game/'+name)
        for name in data['live_policy_differences']:z.write(root/'tools'/name,'live/tools/'+name)
        for c in CAPTAINS:
            for d in range(4):z.write(root/f'artifacts/trained-captain-rates-livecheck-{c}-{d}.json',f'validation/live-{c}-{d}.json')
        for c in CAPTAINS:
            for label in ['pilot','diskcheck']:z.write(snapshot/f'artifacts/trained-captain-rates-{label}-{c}-0.json',f'validation/{label}-{c}.json')
        z.writestr('manifest.json',json.dumps(data,ensure_ascii=False,indent=2))
    for r in data['rows']:print(r)
    for p in data['pairs']:print('PAIR',p)
    print('TRAINED_SUMMARY_VERIFIED: 6000 equal-105XP runs, all routes paired, training and talent records audited.')


if __name__=='__main__':main()
