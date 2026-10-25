# Tactical Enemy AI and Paired Difficulty Study

**Goal:** Ordinary enemies and bosses coordinate target/skill choices, use actual walkable terrain and preserve attack AP, avoid known hostile traps and imminent shrink, and retain counterplay under affix/skill combinations.
**Architecture:** A deterministic EnemyAI helper ranks legal actions using isolated real-rule snapshots. Skill target validation is shared with actual casting. Movement uses board geometry and public unit stats, not hidden player inputs; known hazards differ by faction. Boss warning targeting may select a tactical target at preparation only, with frozen intents unchanged.
**Tech Stack:** Godot4 GDScript, headless regression and same-state classic-vs-tactical policy simulations.

## Contracts
- No new damage/stat/cooldown bonuses. No hidden-state access or random hit decisions. Deterministic ties, finite AP, one enemy active per turn, actual CD unchanged.
- Evaluate kills, effective HP/MP loss, shields/guard, mark setup for reachable allies, nonduplicated control, useful recovery/barriers/command. Don't spend support cooldown if there is no value.
- Seek safe firing distance/chokepoints by movement/path reach; obstacles affect movement only (current rules have no line-of-sight/cover mitigation).
- Avoid hostile traps and impending shrink cells; friendly boss warnings do not harm enemies under current rules. Track no artificial invulnerability or unit teleportation. Existing real action playback remains authoritative.
- Keep a classic policy only in test tooling for same-rules paired experiments. Record affix, skill mixture, map seed, resources, build, wins/deaths/rounds/HP/MP, invalid moves/stalls and public AI reasons. Reject reports if sources change midrun.

## Tasks
1. tests/enemy_tactics.gd failing scenarios: coordinated focus, skill-vs-attack, no useless mark/command/shield/heal, ranged spacing, safe retreat, path around obstacles/traps, shrink safety, deterministic decision/no mutation, boss target and valid AP/CD execution.
2. Implement game/enemy_ai.gd + minimal rules/skills/region preparation hooks. Share legal-target checks. Log brief actionable intent reasons.
3. Independent tools/simulate_enemy_ai.gd + tests/enemy_ai_balance.gd compare classic and tactical with equal parties/resources/seeds and affix/lineup stress. Review actual results before any numeric tuning.
4. Full verify.py, performance check and fresh-context review; document observed limits and actual results. Preserve existing pending work and no automatic commit of mixed changes.

## Execution evidence
- Implemented snapshot-based action selection, shared skill validation, tactical preparation target, real-path movement and public hazard handling. Original combat stats/AP/CD and frozen intent rules retained.
- Regression suite covers lethal target selection, marks for allies, useful support, ranged spacing, trap detours, shrink timing, trapped-edge attack, long-wall detours, purity/determinism and bounded real turns: 447 checks.
- Independent review confirmed fixes for hazard delta scoring, real shrink rounds and BFS detours, with no further actionable AP/CD issues.
- Paired final study completed 744/744, valid=true, stale=false, invalid actions=0, stalls=0, unfinished=0. Corrected tooling to recognize the actual gameover terminal outcome instead of treating player defeats as incomplete games.
- AI raised total companion deaths but also player wins under the fixed player policy; README records both results and region/build differences. No numeric buffs applied.
- Final full verification: 71,158 checks across 57 suites, scene smoke and native appearance/equipment preview rendering passed; git diff --check clean. Final study source fingerprints still match current files.
