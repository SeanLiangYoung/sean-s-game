# Six-Region and Cross-Theme Balance Implementation Plan

**Goal:** Ease marsh attrition moderately, increase frost/ruins threat through their existing mechanics and make shield/lifesteal stacking carry a visible tradeoff while retaining viable counter-builds.
**Architecture:** Freeze the current entire gameplay source before edits, including other chats' existing blood-four and command-four updates. Use exactly the same scenario runner in independent Godot projects for baseline vs final; equal parties, training, relic bindings, seeded terrain and single affix. Tune current mechanics and explicit item costs, not arbitrary item-ID immunity or removal of escape/control counterplay.
**Tech Stack:** Godot4 GDScript, real-rule unit tests, baseline/final paired JSON cohorts and held-out seeds, full native scene verification.

## Design
- Keep border/wood/waste mechanics; protect regional counterplay: cleanse and shields for poison, expose/traps for armor, stagger for overload.
- Marsh reductions should touch poison/attrition or tactical pressure, not erase poison. Frost and ruins should apply useful control/MP pressure and have meaningful but interruptible/avoidable boss skills.
- Blood/ward weakness should come from an explicit sustain-versus-protection tradeoff with matching inventory/battle descriptions. Preserve legal 2+2 combinations and pure-family identity, personal binding, no hidden item targeting.
- Avoid blanket nerfs to all healing or buffs to every monster; validate whether reduced perfect-win cross builds still provide an advantage in suitable regions.

## Execution
1. Freeze current game source in a temporary Godot project and artifacts/region-retune-baseline-game.zip. Add independent tools/simulate_region_retune.gd + tests/region_retune_balance.gd with eight themes and focus cross builds/captains; copy the same finalized tools into frozen project. Run baseline and save hashes.
2. Write failing tests in tests/region_retune.gd for intended live modifiers, shield-dependent lifesteal, poison/regional cooldown/mitigation and unchanged counterplay. Implement minimal changes in game/rules.gd, relic_expansion.gd, region_combat.gd, enemy_skills.gd and regions.gd as justified; preserve IDs/saves and other pending edits.
3. Run tuning cohorts then full baseline/final and independent held-out seeds. Compare per-region/resource/build/captain, deaths/HP/MP and paired reversals. Revise if directions fail or counterplay vanishes; no claims based on old stale studies.
4. Read-only implementation review; full tests/verify.py and native rendering; verify report fingerprints and same runner. Update README with actual sample bounds, selected numbers, observed advantages/weaknesses and reproduction. No automatic commit of mixed work.
