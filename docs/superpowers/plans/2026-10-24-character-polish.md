# Character Polish Implementation Plan

> Execute inline using superpowers:executing-plans, with final independent review.

**Goal:** Distinct original costume layers and complete staged skill choreography.
**Architecture:** New character wardrobe helper builds torso-bound curved cloth and accessories; shared shaders preserve source textures. CombatPresentation owns explicit release time and charge effects while CharacterVisual maps preparation actions.
**Tech Stack:** Godot 4.7.2, GDScript and spatial shaders, existing CC0 rigs.
**Spec:** docs/superpowers/specs/2026-10-24-character-polish-design.md

## Constraints
No rule/save changes. Original geometry/shaders only; no copied reference-game assets or purchases. Preserve imported source files. Skill visual timing may be slower than ordinary attack, with input still locked.

## Review Focus
Attachment drift; weapons/capes intersecting; projectile visible before release; large frame delta skipping release; death/reward overlap.

- [ ] Add failing checks for wardrobe on allied rigs, bow draw before release, no early projectile, once-only release/impact and healing stage behavior.
- [ ] Create game/character_wardrobe.gd and character/garment shaders; integrate role palettes and torso attachments in CharacterVisual.
- [ ] Add staged release and charge presentation, map preparation clips, retain action cleanup and death timing.
- [ ] Run full suites and inspect native close-up/skill captures. Independent review, document limitations, save iteration.
