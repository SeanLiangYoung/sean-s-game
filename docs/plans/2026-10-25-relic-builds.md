# 遗物构筑与基础装备 Implementation Plan

**Goal:** 110件遗物承载局内构筑，装备同类型仅低中高三档、属性种类一致。
**Architecture:** 保留30件已有遗物并新增8个主题各10件，2/4件共鸣按角色实际适用遗物计算。条件伤害、回合恢复、护盾和击杀行动点接入真实战斗与自动战斗预演。战后五选一含3件不同遗物，兼容旧三选一存档。装备保留旧ID兼容，只提供小幅基础属性成长。
**Tech Stack:** Godot 4 / GDScript。

1. 新建 tests/relic_builds.gd 与 tests/equipment_tiers.gd，先验证目录、共鸣隔离、触发边界、战利品与装备档位，运行观察失败。
2. 新建 game/relic_expansion.gd；game/relics.gd 集成目录、共鸣与说明；game/rules.gd 接入触发。
3. game/campaign.gd 扩大战后遗物选项并迁移旧奖励说明；game/main.gd 展示共鸣进度与五选一。
4. game/professions.gd 将装备改为基础属性三档，保留类型、职业适应与武器基础射程；修订相关旧断言。
5. 完整运行 tests/verify.py，修复回归并更新README。直接增量修改当前工作区，保留已有修改。
