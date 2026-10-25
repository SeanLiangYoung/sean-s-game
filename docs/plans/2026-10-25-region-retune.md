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

## Discarded candidate results (snapshot round-start bug; not final evidence)
- Baseline frozen before edits; preserved prior blood4/command4 updates. Two original768-case cohorts plus two240-case all-team variant cohorts per version produced2016 matched scenarios. Baseline2016 + firstpass2016 + owner-cost delta240 =4272 formal actual executions; final1776 unaffected rows reused with byte-level combat-source and relic-ID proof.
- Implemented per-entry shielded banner cost; blood2/ward2 shifted some resonance tofour; ward1/ward6 automatic barriers reduced; ward6 wearer-only recovery−25%. Pure-family total resonance preserved.
- Poison2x2, marsh captainpriority1.5; frost2-cell retaliation and stronger cold strikes; core10/6 and active siphon4/full-shield1; real snapshot resolve for intent HP/MP valuation. Reviewer caught phantom drain under shield_taken/armor floor, fixed with RED→GREEN regressions. Final owner-cost review had no findings.
- Main regression36 checks; study contracts904+288+268; full verification89590 checks across70 suites +native rendering passed. First native timeout happened under six concurrent study processes; standalone and complete reruns passed without changing timeout.
- Direction gate:marsh wins282→287, frost298→297, ruins305→299, each336 cases. Region win spread6.8→3.6pp. Marsh death count211→222 remains a limitation and is explicitly reported.
- Blood/ward variants711/720→691/720; personal237/240 but higher attrition. Exact matched hunt comparisons show losses where hunt wins plus slower/more-casualty victories; do not claim universal builds eliminated outside samples.
- Raw reports, frozen baseline/firstpass/final archives, sha manifest and reproducible summary saved under artifacts. Mixed workspace left uncommitted.

## Experimental harness correction
- Found that Rules.auto_snapshot() instantiates StudyRules with default preparing=true; exhausted last actors could skip next-round rebuild and turn-start effects. Original simulations are withdrawn as final evidence and archived under discarded-candidate.
- Added minimal auto_snapshot override to both StudyRules wrappers, preserving preparing state; observed RED3 failures then GREEN (retune909, coordination2714), including real round/order/turn_serial transition and authoritative state isolation. Variants288/personal268 still pass.
- Both baseline and latest full final projects receive identical corrected tools. Re-running all4032 formal games (2016/version), with no reuse or personal-delta overlay. Native verification will run after heavy simulations to avoid CPU-induced render timeout.

## Corrected final evidence
- All4032 games fully rerun after the preparing snapshot fix, no candidate/delta reuse. Baseline and latest final each2016, same active policy tools byte-for-byte, primary and heldout cohorts each1008/version. All reports valid=true/stale=false/invalid0/stalls0/unfinished0; all eight logs contain no script errors.
- Corrected final:marsh282→287 wins, frost298→297, ruins305→299 (336 cases/version/region). Frost deaths159→185; ruins151→169; marsh211→222 limitation remains. Region win spread6.8→3.6pp.
- Blood/ward711/720→691/720; personal237/240 but deaths170→198. Exact96-case hunt comparison confirms2 personal losses where hunt wins and33 higher-casualty/70 slower wins out of82 mutual wins. Pure blood187→191 and ward227→229 remain viable.
- Full current verification89727 checks/71 suites, scene smoke and both native renders passed. Live relics.gd differs only in draft_rewards (parallel loot work); precise function-body exclusion proves all other relic logic identical and confirms no battle driver/dependency calls drafting. Fixed-loadout evidence is unaffected, no relaxation for combat changes.
- Reproducible final summary, baseline/final archives and sha manifests regenerated; discarded candidate data/source archives are clearly separated. Current workspace changes remain uncommitted.
