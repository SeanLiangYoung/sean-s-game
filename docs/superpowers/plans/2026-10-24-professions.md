# Profession Core Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Separate characters and professions, deliver equipment tradeoffs, camp retraining and six tactical roles.

**Architecture:** A new `game/professions.gd` owns declarative professions, skills, equipment and pure derived stats. Campaign owns permanent changes and migration; Rules owns temporary combat state; Main renders these contracts.

**Tech Stack:** Godot 4.7 GDScript, existing headless suite and native screenshot captures.

**Spec:** `docs/superpowers/specs/2026-10-24-professions-design.md` (approved).

## Global Constraints

- No profession levels or proficiency. No combat equipment changes.
- Hero profession is exclusive to Shen; identity, appearance and death rules remain character based.
- Every item is wearable; hero has no profession specialization or equipment penalties.
- Existing unrelated uncommitted artwork changes must be preserved.

## Review Focus

- Repeated load/equip/retrain must not accumulate derived stats.
- Rejected save data must leave live campaign untouched, including nested snapshot.
- A dying state source must not leave permanent protection or marks.
- Movement interrupted by traps must show the actual traversed path.
- Multi-skill menus and long equipment previews must remain scrollable and readable.

### Task 1: Permanent profession and equipment state

Files: create `game/professions.gd`, `tests/professions.gd`; modify `game/campaign.gd`, `game/rules.gd` default party.

Interfaces: `Professions.stats(unit, equipment) -> Dictionary`, `skills_for(unit) -> Array`, `can_learn(unit,id) -> bool`; Campaign `change_profession(id,job) -> bool`, `preview_equipment(index,id) -> Dictionary`, slot-aware `equipped_index/unequip_item`.

- [x] Write failing tests for distinct profession IDs, same profession on multiple characters, retraining without healing, plate penalties, hero exceptions, transfer, invalid ownership and v1 migration.
- [x] Run new headless test and confirm missing behavior.
- [x] Implement catalogs, derived stats, camp changes, inventory, books and transactional version 1/2 load.
- [x] Run new test plus equipment, persistence and routes tests.

### Task 2: Tactical professions and aura

Files: modify `game/rules.gd`; create `tests/profession_combat.gd`.

Interfaces: Rules `available_skills(unit)`, `can_cast(skill,target)`, `cast(target,skill="")`, `aura_description()`, `status_text(unit)`; target is character ID or Vector2i for traps. Temporary states remain in battle only.

- [x] Write failing combat tests for skills, once-per-turn costs, aura deployment, trap interruption, state expiration, guard splitting and death cleanup.
- [x] Implement deterministic skills, damage routing, per-turn AP, traps and aura.
- [x] Run new combat tests and all existing rule/action suites; adapt obsolete expectations only where approved behavior changes them.

### Task 3: Player-facing integration

Files: modify `game/main.gd`, `game/combat_presentation.gd`, `tests/verify.py`; create `tests/profession_ui.gd`.

Interfaces: Main selected_skill feeds Rules; character/profession/equipment pages consume the same stats as combat. Presentation receives effect style from skill rather than character identity.

- [x] Write a failing scene test for retraining page, slots, equipment preview and selecting an empty-cell skill.
- [x] Add profession page, equipment comparison, book availability, aura preview, skill menu and trap/status rendering.
- [x] Verify UI tests and screenshots; run full `python3 tests/verify.py`.
- [x] Run fresh whole-change review, fix substantive findings with regression tests, update README and implementation ledger.

## Execution ledger

Ruling: execute in the existing feature branch to preserve the user's active game and uncommitted presentation work; no extra worktree or plan-approval round is needed after explicit implementation authorization.


Task 1: complete — permanent state tests, slot ownership, camp retraining and v1/v2 migration implemented.
Task 2: complete — profession skills, per-turn states, equipment AP and deployed hero aura implemented.
Task 3: complete — dossiers, retraining, comparison previews, multi-skill controls, trap tiles, status feedback and dash movement implemented; native screenshots inspected.

Review: fresh reviewer identified lethal-trap turn deadlock and two malformed-save validation paths. Added reproducing tests, observed failures, fixed turn progression and type/base-field validation. Added aura death cleanup and action feedback regressions.
Ruling: keep the current feature branch and local work in place; integration/publishing was not requested.

Final verification: `python3 tests/verify.py` — 487 checks across 17 suites, zero failures or script errors, native scene smoke passed. `git diff --check` passed. Screenshots rendered and visually inspected with native Godot.
