# Equipment Shape Polish Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans; use existing behavior and native pixel regressions for this reversible geometry-only refinement.

**Goal:** Replace box-like armor and coarse equipment with fitted curved forms and readable crafted details, while preserving character identity and equipment synchronization.

**Architecture:** Add shared procedural mesh helpers for curved shells, extruded silhouettes and swept bands. EquipmentVisual composes these meshes on the existing bone mounts. Keep profile, inventory, stats, portrait cache and animation contracts unchanged.

**Tech Stack:** Godot SurfaceTool, native primitive meshes for small fasteners, existing skeletal attachment and animation resources.

**Spec:** User requested body-fitting armor and finer weapon/shield modeling; current style remains stylized fantasy.

## Global Constraints

- Preserve all equipment statistics, professions, slot behavior and save data.
- Preserve faces, hair and recognizable underclothes.
- No dependencies, downloads or new raster assets; refine in native 3D geometry.
- Keep attachment identities and animation paths compatible with existing tests.
- Existing unrelated uncommitted artwork changes remain untouched.

## Review Focus

- Curved armor must cover underclothes without making torso excessively bulky or clipping arms in attack poses.
- Greaves, bracers and shoulders remain separately bound to their bones.
- Blade tips, shield rim and bowstring must render from front and back without reversed faces.
- Fine details must remain readable in 192px portraits and normal battlefield scale.
- Old portrait caching, equipment transfer and unequip restoration must remain valid.

### Task 1: Refine geometry

Files: new game/equipment_shapes.gd; modify game/equipment_visual.gd.

- [x] Build tapered curved cuirass and leather vest, rounded neck/waist edges, overlapping abdomen plates and shaped shoulder/limb shells.
- [x] Build curved wooden shield with rim, planks, rivets, boss and rear grip/straps.
- [x] Refine sword/dagger blades and hilt, bow limbs/string, staff head/grip, and crossbow stock/limbs/trigger/bolt.
- [x] Run existing attachment, animation and rendered portrait regressions; repair geometry or regressions.

### Task 2: Visual QA and delivery

Files: tools/capture_equipment.gd, new tools/capture_equipment_detail.gd; README and this plan.

- [x] Preserve the before lineup, render updated lineup, closeups and attack poses; inspect all six people and all equipment categories.
- [x] Adjust fitting, silhouettes/materials and any visible intersections based on renders.
- [x] Fresh independent review, full python3 tests/verify.py, diff check, update documentation and commit only this change.

## Implementation decisions

This is a direct refinement request with a defined visual problem; proceed in the current feature branch. No extra gameplay changes or art-style approval round. Use existing native render pixel tests rather than tests that assert an aesthetic implementation shape.

### Task 3: Independent character pages (user steering)

User additionally requested independent details / equipment / skills pages. Keep the selected character across pages; move skill/book management to Skills and leave identity, stats and derived effects on Details. Keep roster and current character header visible while long equipment/skill contents scroll independently. Retain Profession for camp retraining and shared Items/Relics pages. Existing callers using "角色" open Details.

Files: game/main.gd, game/party_details.gd, tests/character_pages.gd. Add scene regressions for content separation, selection retention, skill learning and independent scrolling; render all three pages and include in final review.


## Execution ledger

Task 1 complete: fitted shell armor, separate limb pieces, dished shield, original crafted weapon geometry. Reuse native grip frames and animation library only; gear stats/profiles unchanged.
Task 2 complete: retained before screenshot; rendered and inspected six-role lineup, front/side/back armor, dagger/leather, shield rear and weapon closeups. Corrected Godot clockwise triangle winding after the first native render exposed culled surfaces; three RED→GREEN normal-direction tests prevent recurrence.
Task 3 complete: Details, Equipment and Skills are separate views with fixed identity header and independent roster/content scrolls. Skill books moved to Skills. Scene tests cover content boundaries, learning, selected character/page retention, old Character alias and shared inventory.
Independent review: no actionable findings after checking winding, bone transforms, UI content separation, phase restrictions and modal replacement.
Ruling: keep all work on the current feature branch; preserve unrelated pending art edits.

Final verification: `python3 tests/verify.py` passed 819 checks across 22 suites, including native pixel rendering and scene startup; `git diff --check` passed. Inspected character-details.png, character-equipment.png, character-skills.png, equipment-appearance-lineup.png and equipment-shapes-detail.png.
