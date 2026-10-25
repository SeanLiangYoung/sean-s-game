# Six Boss Phases, Presentation and Build Balance

**Goal:** Give all six bosses an explicit half-health phase change, distinctive rig-attached silhouettes and timed charge/release effects, readable warning timing and paired build balance evidence.
**Architecture:** Region data defines two phase identities. Rules latch phase2 once at <=50%HP, append structured visual cues, and freeze each prepared intent's shape, phase and payload. Presentation consumes action-local cue copies, never changes tactical state, and supports cues from a different actor when turn advancement resolves a boss spell. A deterministic paired simulator uses the same skills, gear budget, starting resources, seeds and policy across build families.
**Tech Stack:** Godot GDScript, procedural geometry with existing CC0 skeletons and native clips, headless tests and native rendered captures.

## Behavior contract
- Half health is a single latched transition; damage from attacks, skills and traps can cause it. No extra action, instant hit, invulnerability or HP refill. Healing cannot return to phase1.
- A prepared warning never changes on transition; phase2 applies only to new preparations. Death and shrinking still cancel it. Capture payload damage/shape so warnings remain honest.
- Border phase2 adds a modest damage volley to marked command cells; wood adds root cells and modest damage; waste switches a single sandline to a bounded cross; frost lowers renewed shield and becomes more offensive; marsh expands bloom cells while poison remains two nonstacking ticks; ruins expands overload while stagger still interrupts.
- At most7 cells and at least one reachable safe destination for a warned ally when movement AP is sufficient. No unavoidable all-board charge on late rings: trim warning candidates where needed. Ordinary modifiers/guards/shields still apply.
- Phase name, threshold and current warnings visible in a dedicated boss panel. Warnings use region color plus distinct glyphs and phase markers, labels state next boss action, damage/debuff and interruption rules.
- Boss attachments follow bones; silhouettes differ by banners/antlers/spear/ice/fungi/core. Phase2 changes emissive accents and grows/unfolds ornaments. Native clips plus procedural weight shifts provide charge, release, interrupt and transition animations.

## Task sequence
1. tests/boss_phases.gd: observe missing phase behavior; implement phase catalog, one-time transition, frozen intents, phase2 payload and warning fairness.
2. tests/boss_presentation.gd: observe missing boss HUD/attachments/action cues/effects; implement decorations, cue-aware presentation and warning UI. Verify pose/effect timing and no rule mutation.
3. tools/simulate_boss_balance.gd: paired baseline + four equal-budget builds x6regions xseeds, full and depleted entry cases; record wins/deaths/rounds/HP/MP, phase transitions and invalid actions. Compare and tune only observed issues; don't impose universal wins.
4. Full tests/verify.py, actual phase1/phase2/charge/release/interrupt captures, independent fresh-context code review, README and execution record.

## Workspace
Continue incrementally with existing expansion, relic, battlefield and difficulty changes. Do not reset, overwrite unrelated work or commit mixed changes automatically.

## Additional user requirements
- Every battle rolls exactly one enemy-only self-enhancing affix; independent deterministic RNG, one affix on one enemy, stable on retry/reload. Visible in deployment and combat.
- Every ordinary enemy gets an active skill; all enemy skills consume AP and cooldown, never MP. Cooldown counts the owner's turns and is actor-local.
- Each boss has >=3 active skills, >=1 passive and a regional trait. Keep phase-change and distinct visual/animation goals. Bound active skill usage to one per personal turn so AP and damage bursts remain readable.
- Three boss actives: regional delayed intent (CD2), regional targeted strike (CD2), regional self/ally support (CD3). Passive and region trait are distinct documented records. Existing normal attack/movement remain fallbacks. Cooldown starts only when action succeeds, preparation/interrupt still spends cooldown.

## Completion record
- Phase/catalog rules and all three active skills per boss implemented. Enemy skill suite889checks, phase suite77. Exactly one deterministic affix per encounter, cooldowns independent per actor, no enemy MP cost.
- BossVisual and BossEffects helpers independently implemented and integrated; silhouette/rig/effect tests130checks and actual-scene presentation73checks. Source-aware cues preserve spells resolving on another actor's turn; empty-cell effects render.
- Review fix: enemy dash must interpolate its captured path even when classified as an enemy skill; actual scene regression now verifies travel before impact.
- Integration fix: warded affix must add to innate barriers; capacitor shield skill can upgrade its smaller innate shield. Fair warnings use actual next-turn movement allowance.
- Paired360-case study complete: source hashes unchanged, invalid actions0, phase2 reached346. Same 300XP budget/actor,285spent,210silver gear; four-relic builds vs zero-relic control. Full-resource all groups36/36; depleted control20,blood28,hunt33,ward31,arcane34 wins out of36. Retain tradeoffs rather than overfit one policy/cohort by forcing equal wins. Report artifacts/boss-balance-baseline.json.
- Final regression passed61813checks across54suites, scene smoke/native appearance/preview rendering passed. Enemy skill889checks exercise all18 boss actives. Reviewer independently confirmed enemy dash, AP-aware warning fairness and shield-affix integration fixes. Current game source fingerprints still match the360-case report.
- Six-region native phase1/phase2/charge/release/detail captures inspected. Existing rigs/clips retained; procedural bone ornaments, poses and per-region VFX add distinction.
