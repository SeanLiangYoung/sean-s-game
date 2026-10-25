# Regional Enemy, Boss and Scenery Implementation Plan

**Goal:** Give each of the six regions two identifiable enemy archetypes, one telegraphed boss mechanic, distinct scenery, and explicit build counters.
**Architecture:** A shared region catalog owns names, traits, intent data, colors and counter hints. Rules own all temporary battle state and resolve intents at the next boss turn; presentation only reads it. Existing seed generation and pre-battle checkpoints remain compatible; legacy encounters without biome configuration keep their old rules and scene.
**Tech Stack:** Godot GDScript, existing procedural art and rigged character assets, headless combat/scene tests plus native screenshots.

## Design
- Border: formation melee / marking spotters; commander orders mark and limited one-hit buffs. Cleanse, guard and splitting enemies answer coordination.
- Wood: ambush melee / camouflaged archers; boss roots telegraphed cells. Mark, close attacks and traps bypass concealment; cleanse removes movement snares.
- Waste: wounded raiders / mana-sapping bowmen; boss sand lance telegraphs a hex line. Control, mobility and finishing attacks prevent rage pressure.
- Frost: first-hit frost armor / chilling ranged attacks; boss renews ice shield unless exposed and telegraphs cold cells. Armor break, shield and cleanse counter protection and chill.
- Marsh: draining melee / poison archers; boss poisonous blooms. Poison has two nonstacking ticks and can be cleansed; healing and kill sustain counter attrition.
- Ruins: shielded constructs / mana drainers; boss telegraphs overload that stagger can interrupt. Exposed blocks shield renewal; traps consume barriers; mana support and stagger have explicit value.
- Each boss spends AP to prepare, resolves only next own turn, and can act afterward within ordinary AP. At most five danger cells; death/shrink cancels stale warnings. Warnings, trait descriptions and counter hints visible before and during combat. No new random hit rolls or immunity requiring one specific item.
- Ground palettes, prop silhouettes, lights, enemy gear and boss accents differ. All physical obstacles remain defined by rules; decorative scenery stays outside the playable arena.

## Steps
1. Write tests/region_combat.gd for traits, counters, poison/chill/snare lifecycle, intent delay/escape/interrupt/cancel and snapshot isolation. Observe missing region behavior, implement catalog and rule hooks, verify.
2. Write tests/region_scenes.gd for scene identity, variant pawn gear, warning visibility and predeployment counter information. Observe missing presentation, implement regional scenery and UI, verify.
3. Exercise generated routes across seeds and representative tactical parties; keep initial tiers within previous enemy-count/power bounds and adjust only from observed outcomes.
4. Run full tests/verify.py, native six-region captures, fresh read-only review and fixes. Update README with exact mechanics, counters and asset limitations.

## Work record
- Continue in existing workspace/branch, retaining all prior pending expansion and UI work. No reset or automatic commit of mixed changes.
- Tasks 1–2 complete: region catalog, twelve enemy identities, six boss intents, counter briefs, six scene builders and regional enemy gear/insignia. Focused combat suite expanded to84 checks; scenes45 checks.
- Task3: tier-two equipped/skilled counter builds won18/18 seeded boss encounters, in2–3 rounds. Current basic starter expedition smoke remains separate from prepared-build validation.
- Integration ruling: workspace concurrently gained random battlefield/deployment generation, 110-relic resonances, basic equipment tiers and updated difficulty calibration. Retained these changes and revised region counter hints to describe current basic gear rather than removed gear modifiers; made no rollback to earlier catalogs/calibration.
- Review fixes: border enemy catalog must be ranged-first like other five regions; auto movement must exclude warned destinations after escaping and reject simulated landings in danger. Regression cases passed and reviewer confirmed.
- Poison ruling: start-turn regenerative/shield relic triggers precede poison damage, making these builds reliable counters. Debuffs remain finite, nonstacking and cleansable; fatal poison still advances safely.
- Final full verification:58026 checks across45 suites passed, including84 regional-combat checks,45 regional-scene checks and18/18 prepared-build boss victories. Scene smoke and native appearance/preview rendering passed. Native screenshot QA inspected forest/desert/frost/marsh/ruins distinct silhouettes and readable warnings.
