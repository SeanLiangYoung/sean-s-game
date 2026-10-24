# Natural Characters Implementation Plan

> Use superpowers:executing-plans inline with a final independent review.

**Goal:** Show clothed human-proportion fantasy characters with distinct professional actions.
**Architecture:** Preserve CharacterVisual and timeline APIs; replace backend resources and expose effect style from the same role mapping.
**Tech Stack:** Godot 4.7.2, CC0 glTF.
**Spec:** docs/superpowers/specs/2026-10-24-natural-characters-design.md

## Constraints
No purchases, no battle/save changes. Preserve original CC0 sources and download provenance. Missing rest motion needs visible gesture/posture rather than silent idle.

## Review Focus
Model orientation; mesh scale; absent clips; rest pose cleanup; ranged enemy and healing effects remaining readable.

- [x] Add a failing character suite: all supported roles have humanoid rigs, correct declared backend and valid logical action clips; healer skill has healing effect profile and archer uses bow motion.
- [x] Import and inspect Quaternius RPG models, map roles and actions with normalized scale and fallback rest gesture.
- [x] Distinguish melee skill wave, arrow and healing bolt effects; verify presentation regressions and native lineup/action captures.
- [x] Run full verification, independent review, update asset records and save the completed iteration.
