# 佣兵远征原型 Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement inline. User authorized autonomous implementation and iteration on 2026-10-22; routine approval gates are waived.

**Goal:** Deliver a locally playable 3D expedition prototype with tested tactical rules.

**Architecture:** Godot 4, procedural low-poly environment, independent deterministic rule state. UI and 3D scene read rule state; they cannot bypass combat or expedition validation.

**Tech Stack:** Godot 4.7.2, GDScript, native headless tests, procedural meshes.

**Spec:** docs/superpowers/specs/2026-10-22-mercenary-tactics-design.md

## Global Constraints

- Max roster 10, deployment 5; fixed hero death ends game.
- Hex tactics, 4 AP, speed order, exclusive HP/MP rest.
- Persistent wounds, three-choice rewards, two relic extraction limit.
- Timeout kills deployed units, encounter cannot retry, reserves survive.
- Shrinking board: warning, displacement, damage, no destination means death.
- Prototype on Mac; future desktop/iOS targets, no store publishing in this task.

## Review Focus

- Repeat clicks must never duplicate rewards or resolve AI twice.
- Dead or reserve actors never occupy a tactical tile.
- Extraction cannot retain more than two relics, even after reopening UI.
- Hero death and timeout take priority over ordinary combat continuation.
- Save loading validates schema; snapshot restores pre-expedition state.

## Task 1: Tactical simulation

Files: game/rules.gd, tests/run.gd, project.godot.
Interface: Rules.new(), start_battle(ids, difficulty), move_to(cell), attack(id), cast(id), rest(kind), finish_turn(), shrink(), outcome; dictionary units and axial Vector2i cells.
- [ ] Write assertions for movement/AP, speed, HP/MP rest, deadline, displaced actors and hero death.
- [ ] Run headless test runner and observe missing implementation fail.
- [ ] Implement deterministic hex grid and combat, enemy pursuit and actions.
- [ ] Run headless tests; all assertions pass.

## Task 2: Expedition and persistence

Files: game/campaign.gd, tests/run.gd.
Interface: Campaign.new(), depart(), resolve_battle(rules, encounter), choose_reward(index), extract(indices), save_game(), load_game(snapshot).
- [ ] Add failing assertions for reward uniqueness/single claim, permadeath, reserves, failed encounter lockout, persistent HP/MP, extraction cap and snapshot restoration.
- [ ] Implement campaign transitions using the tactical module; local JSON saves with schema checks and atomic replacement.
- [ ] Run complete rule suite.

## Task 3: Playable presentation

Files: game/main.gd, game/main.tscn, README.md, launch.command.
Interface: main consumes Campaign and Rules, renders native 3D world and hex board, binds pointer selection and action buttons.
- [ ] Add integration smoke tests covering departure through extraction and combat failure.
- [ ] Build low-poly borderland, camp, three encounters and exit; world click-to-walk, camera, scene transition, roster, deployment, rest preview, timeline and combat log.
- [ ] Build reward, extraction and game-over overlays, saved continuation and snapshot reload.
- [ ] Headless import and launch smoke check; inspect rendered screenshot, fix visual issues.
- [ ] Play and simulate expeditions; adjust test numbers if no meaningful tactical choices.

## Completion

- [ ] Run all tests and headless scene smoke test, review implementation, fix material findings.
- [ ] Document controls and actual limitations; provide launcher and local game.
