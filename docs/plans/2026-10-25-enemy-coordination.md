# Enemy Coordination and Regional Balance Implementation Plan

**Goal:** Improve focus without ignoring attainable kills or overcommitting to protected captains; demonstrate equal-rule difficulty against both previous AI policies and calibrate regional outliers.
**Architecture:** Keep a frozen previous planner for tooling only. Compute public-state reachable follow-up damage and target value, favor captain pressure moderately, and compare actual damage/support with moves that retain attacks. No hidden player decisions, no persistent arbitrary target lock and no MP/CD exceptions. Paired expanded simulations share actors, map, training, skill profiles, relic legality and one affix; include held-out seeds and report region/resource/build segments rather than just aggregate wins.
**Tech Stack:** Godot GDScript rules, headless fixtures, paired JSON studies, full scene/native render verification.

## Tasks
1. Preserve tools/enemy_ai_previous.gd; write failing tests in tests/enemy_coordination.gd for captain vs other kills, reachable follow-up, safe focus movement, no meaningless pursuit/retreat and support synergy. Watch RED; implement bounded real-rule scoring in game/enemy_ai.gd; run old tactics tests.
2. Independently build tools/simulate_enemy_coordination.gd and tests/enemy_coordination_balance.gd. Retain classic/previous/current policies with exact same current rules. Expand to all seven affixes including boss slots, native/mixed skill lines, all relic themes and legal cross-theme builds, alternate funded skill profiles and full/depleted resources. Preserve old reports.
3. Compare a small tuning cohort, fix actual decision regressions, then run full and held-out cases. Inspect six regions; make measured regional policy calibration rather than uniform stat inflation. Record changes, confidence limits and failures honestly.
4. Review pure deterministic decisions, AP/CD and hazards; full tests/verify.py + source fingerprints + git diff --check. Append README evidence. Do not commit mixed workspace changes.

## Acceptance
- No free actions, no cooldown changes, one affix per encounter and one active per turn retained.
- Attainable captain kill wins; an obvious other kill remains preferable to ineffective captain pressure. Common reachable targets receive coordinated approach; walls, shields and healing opportunity affect real effectiveness.
- Expanded same-state current player win rate must not exceed previous AI on aggregate or hide severe regional regression. Report remaining segment regressions, avoid tuning only training seeds.

## Implementation and review evidence
- Preserved previous planner in tools/enemy_ai_previous.gd for three-policy comparisons only.
- Added captain strategy, wounded/support target value, real-path follow-up opportunities, common target approach and a healthy ranged-unit attack-AP reservation rule.
- Calibrated captain priority by region (border1.35, wood1.6, waste/frost1.7, marsh1.8, ruins1.9); these are decision weights, not combat stats. Initial360 tuning games gave current87/120 player wins vs previous113/120 and classic104/120. After timing/mitigation corrections and regional calibration, same current-only cohort gave94/120, border15/20 rather than13/20. These are tuning observations, not final validation.
- Read-only review identified action-window, guard/shield and shared-lane overestimates. Each gained a failing real-rule fixture and was corrected. Follow-up now only includes allies before the target's next action, applies real per-hit damage on a snapshot and rechecks occupied paths after each ally.
- tests/enemy_coordination.gd:28 checks covering captain alternatives, phantom wall follow-up, turn windows, guard, shield consumption, unique melee lane, all six regions' purity and real AP/CD costs. Existing tactical tests passed431 checks.
- Expanded experiment:2088 games per cohort (1080 core +1008 stratified stress), classic/previous/current, seven affixes on ordinary/boss slots, eight relic themes plus six legal cross-theme/base bundles and three equal-budget trained skill profiles. Independent holdout seeds104/137/211.
- Integration tide regression now exercises real paid turns explicitly; stronger deep AI may legitimately end a basic-policy game before first shrink. Introductory victory remains asserted.

## Final validation
- Final and held-out studies each2088/2088 complete, valid=true, stale=false, invalid=0, stalls=0, unfinished=0. Raw source hashes still match current gameplay and study tools.
- All1392 starting-state trios checked identical in party/enemies/map/relics/training. Player wins classic1262, previous1274, current1128 (81.0% vs91.5% previous). Both cohorts individually and all six regions individually pass difficulty comparison against both earlier policies.
- Current regional win rates75.4–84.1%; full-resource690/696 wins, depleted438/696. Advantageous cross-theme defense/sustain builds remain, including blood/ward48/48 vs42/48 earlier; README explicitly reports this counterexample rather than claiming uniform difficulty in every build.
- Full verification:74008 checks across62 suites, scene smoke/native appearance/equipment render all pass. Review has no remaining actionable findings after single-lane fix. git diff --check clean.
