# Fresh-start auto difficulty calibration

> Historical calibration record. The 45–55/100 normal target below has been superseded by the [accepted four-difficulty baseline](../difficulty-balance-baseline-2026-10-25.md): normal 40%, hard 12.5%, nightmare 2%, final difficulty 0% as first-region reference rates. Exact measurements are 382/1,000, 127/1,000, 17/1,000 and 0/1,000. Current gameplay values are retained; neither this older target nor the later 50%/25%/10%/1% targets require further tuning. Zero observed clears does not establish a true probability of zero.

## Final change

Generated road encounters: base enemy HP 32 -> 34, retaining tier scaling,
seeded variation and bruiser HP. Boss HP bonus 40 -> 48, on top of the increased
base (a boss gains 10 HP in total). Longer fights increase action, MP and healing
consumption without increasing enemy burst damage. All generated biomes share
the formulas; the acceptance cohort is the starting border region only.

## Acceptance policy

45-55 clears in 100 fresh campaigns, seeds 2026102500-2026102599. Assign starter
gear to the default hero/blade/ranger/medic/engineer party; prefer battles, then
free supplies; select resource rewards by type; use supplies below 70% HP or 50%
MP. Preserve deaths and injuries. Victory requires defeating the boss and
extracting. Use the real Rules.auto_action planner, not a separate test AI.

## Verified result

52 clears, 48 gameovers. 383 battles, 335 victories. Failed expeditions: 12 at
elites, 36 at bosses. No invalid actions, step limits or reward selection errors.
This is a calibration sample, not a guaranteed probability for every seed/build.

Concurrent region/map/relic work changed the live workspace during calibration.
Intermediate results that failed source checks were discarded. Final simulation
ran against an isolated snapshot; every game script hash matched the live
workspace before its report was copied to artifacts/auto-simulation-border.json.
The report embeds source hashes, seeds, policy and per-battle outcomes, remaining
party HP, survivors and available supplies. Each invocation has a separate
temporary save and removes it afterward.

artifacts/auto-simulation-border-baseline.json preserves the original historical
80/100 result; it predates region/map/relic updates and is not an exact controlled
comparison with the final build. auto-simulation-border-current-control.json is
an intermediate control snapshot (54/100) and also predates some concurrent fixes.

## Regression checks

Tests/auto_difficulty checks generated endurance across all tiers and caps burst.
The older expedition_balance suite uses a separate simple attack/heal policy;
its previous >=5/6-region clear expectation conflicted with increased difficulty.
Its smoke gate is now >=2/6 region clears, >=80% battle wins, and >=18 battles.
The real auto planner's 100-run cohort is the difficulty acceptance check.

Run:
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/simulate_auto_runs.gd
python3 tests/verify.py

Final full verification passed: 58,025 checks across 45 suites, scene smoke and
native appearance rendering. git diff --check passed. Source hashes still match.
