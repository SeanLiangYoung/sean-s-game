# Equipment Full-Body Preview Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans and test-driven-development.

**Goal:** Add a full-body character preview to Equipment with drag rotation, zoom and immediate loadout updates.

**Architecture:** New `game/equipment_preview.gd` owns an isolated SubViewport, lighting, equipped pawn and orbit camera. Main adds it as a fixed middle column on the Equipment tab, independent of the inventory scroll. Per-character view state lives in Main and survives menu rebuilds after equip/unequip/transfer. Use the existing visual profile and geometry builders.

**Spec:** User request: rotating/zoomable full-body character preview, updating live when equipment changes, to inspect armor, weapons and shield.

**Constraints:** Keep gameplay, save files and other character tabs unchanged. Preserve ongoing skill progression work in shared files. Only preview-local GUI events rotate/zoom; world camera stays fixed. Character selection preserves each person's view. Reset restores a full-body view. Switching/closing pages frees preview rendering resources.

**Review focus:** Input capture confined to preview; drag release outside does not stick; zoom limits; profile transfer/unequip consistency; independent preview/content scroll; view state preserved across actual UI equip callbacks; no extra persistent viewports after tab close.

### Task 1: Isolated interactive preview

Files: create `game/equipment_preview.gd`, `tests/equipment_preview.gd`.

- [x] Write and run failing tests for isolated preview, drag/zoom/reset, profile updates, and resource lifetime.
- [x] Implement orbit controls, camera limits, stage and live equipped model using Visual.create.
- [x] Verify targeted headless tests.

### Task 2: Equipment page integration

Files: `game/main.gd`, `tests/equipment_preview.gd`, `tests/verify.py`, `tools/capture_equipment_preview.gd`.

- [x] Add preview column beside equipment list, preserve per-character yaw/elevation/zoom when UI rebuilds.
- [x] Test actual equip/unequip/transfer callbacks update model and retain camera state; no preview on Details/Skills.
- [x] Capture full-body, rotated and zoomed views, inspect layout and weapon fit.
- [x] Fresh independent review, complete suite, documentation and local commit of this feature only.

## Decisions

Proceed using current Godot render/model system and feature branch. Defaults: horizontal drag rotates 360°, vertical drag changes elevation within bounds, wheel or buttons zoom, reset restores centered full-body camera. Preview may crop when deliberately zoomed; reset always shows the body again.


## Execution ledger

Task 1 complete: isolated lit SubViewport, full-body stage, orbit/elevation controls, wheel/button zoom and reset. Drag release outside and lost window focus cancel dragging.
Task 2 complete: fixed preview column, original equipment profile, camera state per character across rebuilds/equip/unequip/selection. Existing shared fullscreen-page work remains intact. Sidebar width preserved for readable roster cards.
Independent review: no confirmed actionable defects. A possible narrow-frustum concern was checked with native rendered bow bounds at four cardinal angles in a tall preview; all fit at the reset view.
Targeted verification: 16 scene/input/equipment checks and 5 native rendered preview checks. Native screenshots inspected for full-body, rear and close views.
Shared workspace contains ongoing unrelated skill progression/relic/fullscreen changes; stage only this preview's additions to shared files, leaving other changes intact.

Final verification: full current-workspace `python3 tests/verify.py` passed 960 checks across 31 suites, including both native rendering suites and scene smoke. Preview-specific coverage: 16 headless + 5 native render checks. `git diff --check` passed.
