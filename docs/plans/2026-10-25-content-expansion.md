# Content Expansion Implementation Plan

**Goal:** Deliver 36 active skills, 24 equipment definitions, 30 relics and six regions with balanced seeded 7–9 stage expeditions.
**Architecture:** Keep stable IDs and existing effects for legacy saves. Add explicit combat modifiers for skill damage, marks, traps, shields, mana and sustain; route generation owns deterministic node types, encounters, stock and events. Campaign persists the generated route seed and RNG state; legacy routes remain five stages.
**Tech Stack:** Godot 4 GDScript; headless rule/scene suites and native rendering.

## Approved design
- Six skills per profession. Basic at top, two intermediate choices, three advanced choices; advanced skills require a rank-two intermediate skill. Skills remain usable across hero profession trees.
- Equipment variants share weapon families and animation rigs, with distinct stat tradeoffs and visible trims. Starting gear remains the eight original pieces; new gear comes from rewards and limited shops.
- Fifteen new relics use composable effects with meaningful risks. Team duplicates do not stack; personal relic slots retain replacement and persistence semantics.
- Six biomes generate 7–9 stages with recovery/commerce opportunities and a final boss. Elite encounters are optional. Enemy counts and stats have hard caps; all starting cells are protected and the central lane remains connected.
- Reward selection guarantees one equipment, one relic and one resource option, without duplicate IDs. Shop stock is limited and saved. No random hit/miss spikes.

## Tasks
1. Add tests/content_expansion.gd: catalog counts, prerequisites, weapon tradeoffs, cross-system damage/heal/mark/trap/guard/mana behavior. Run red, implement definitions and rule hooks, run green.
2. Add tests/expedition_generation.gd: seeds, all six regions, length bounds, recovery and boss guarantees, variation, connected battle boards, stock/choice persistence, legacy route loading and malformed rejection. Run red, implement route and campaign integration, run green.
3. Adapt skill tree to six nodes, new equipment visuals, map layout, battle descriptions and limited shop UI. Exercise actual scene controls in tests/expansion_ui.gd.
4. Update old route fixtures to explicitly request legacy layouts; keep legacy save expectations. Run python3 tests/verify.py and native screenshots. Review whole change and fix confirmed defects.

## Execution record
- Work continues on codex/combat-presentation, preserving all pre-existing uncommitted work. No checkout/reset or automatic commits of mixed changes.

- Completed catalog and combat work: 36 skills, 24 gear definitions, 30 relics. Ranks, equipment and relics compose through explicit modifiers; starting inventory stays at eight items.
- Completed generation: six regions, 7–9 stages, early/preboss recovery and optional elites. 180 region/seed pairs checked for persistence, bounds, free spawns and paths to the center.
- Completed UI: six-node trees, variant equipment visuals, limited shop inventory, region/boss descriptions, build stats and combination hints.
- Ruling: generated boss defeat forces retreat to camp and forfeits expedition relics — ordinary defeat continuation otherwise bypasses the promised boss gate. Casualties and permanent collection remain; covered by regression test and independent reviewer confirmation.
- Ruling: baseline UI tests still targeted superseded direct-equip buttons. Adapted those tests to the existing slot → choice → confirmation flow; did not restore old UI behavior.
- Balance smoke: aggressive starter equipment/basic tactical policy wins 29/30 battles, clears 5/6 regions, maximum four rounds. Check a high clear rate rather than assuming every naive policy must win every biome. Broader seed invariants are separate from this smoke sample.
- Full verification passed 14,022 checks across 38 suites after final skill-description correction. Missing-version rejection was additionally checked in the focused seven-check regression suite. Native captures saved under artifacts/expanded-*.png; README documents retained art limitations and compatibility.
