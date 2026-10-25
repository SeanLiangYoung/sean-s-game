# 遗物流派实战与掉落平衡 Implementation Plan

**Goal:** 以真实战斗对照与实际掉落实验调整八流派，减少泛用必选，提升每局构筑成型和差异。
**Architecture:** 固定种子、队伍与策略测试无遗物/单件/同预算流派，记录胜负、回合、生命法力与死亡；在修改前后复跑。遗物奖励采用每局主题引导、已有主题续接和跨主题探索，保留存档随机状态与旧档兼容。所有规则仍由真实Rules执行。
**Tech Stack:** Godot GDScript模拟、JSON报告、Python汇总。

1. tools/simulate_relic_balance.gd：110单件与八流派六区战场对照；先保存基线证据。
2. tests/relic_balance.gd：针对过强泛用收益、流派续接、主题多样性、去重和读档复现先写失败测试。
3. game/relics.gd / relic_expansion.gd / campaign.gd：依证据调整收益与代价、共鸣和掉落策略；保留110数量及基础装备定位。
4. 复测同种子实战、远征成型率与完整tests/verify.py，保存可复跑报告并更新README。
