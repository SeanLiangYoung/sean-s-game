# Combat Presentation Implementation Plan

> Use superpowers:executing-plans for inline execution and a final independent review.

**Goal:** Replace primitive characters with licensed skeletal models and make every combat action visibly readable.
**Architecture:** Keep deterministic rules intact; a presentation node owns playback and effects while main locks commands and defers redraw/resolution.
**Tech Stack:** Godot 4.7.2, GDScript, CC0 glTF.
**Spec:** docs/superpowers/specs/2026-10-24-combat-presentation-design.md

## Constraints
No purchases, no rule/save changes, no repeated actions during playback, preserve asset license/source. Character pack is provisional pending style feedback.

## Review Focus
Repeated clicks; final kill resolving early; enemy actions bypassing animation; zero-gain rest; movement crossing obstacles.

## Tasks
- [x] Add tests for imported skeletal animation and action input locks, move/attack/rest feedback, delayed victory and enemy playback. Observe missing-feature failures.
- [x] Import complete CC0 character assets, record sources/license; map roles and animation names in game/character_visual.gd, instantiate from game/art.gd.
- [x] Create game/combat_presentation.gd: start(before,after,actor,mode,path), advance(delta), busy flag, impact feedback and completion signal. Integrate player/AI entry points in main.gd, preserve existing direct after_battle_action API for external rule tests.
- [x] Adapt UI tests to complete playback before issuing subsequent commands. Run tests/verify.py and inspect native battle screenshot plus action captures. Review and document remaining style limitations.
