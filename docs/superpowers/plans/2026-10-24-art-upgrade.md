# 断桥哨站视觉升级 Implementation Plan

> Use superpowers:executing-plans inline. User approved the visual direction and authorized starting; routine review gates waived by standing autonomous-work authorization.

**Goal:** Deliver a noticeably upgraded, playable, original stylized 3D battle scene.
**Architecture:** A separate visual factory creates meshes, materials, scenery and characters; main retains interaction and simulation ownership. Procedural geometry and shaders avoid external asset/runtime dependencies.
**Tech Stack:** Godot 4.7.2 Compatibility, GDScript, spatial shaders, MultiMesh vegetation.
**Spec:** docs/superpowers/specs/2026-10-24-art-direction.md

## Constraints
- Preserve combat state, save format, axial positions and mouse picking.
- Use original generated assets and restrained tactical overlays.
- Do not add rendering features unsupported by current renderer.

## Review focus
- Shader compile failures must be checked in native rendering, not only headless.
- No visual animation may mutate actor cells or health.
- Shrinking must keep danger visible and show only current valid tactical cells.
- Repeated scene rebuilding must clear old scenery and animation references.
- World and battle UI retain existing click semantics.

## Task 1: Visual factory
- [x] Add failing art integration test: art factory produces scenery and actors without changing rule state.
- [x] Add game/art.gd plus terrain, vegetation, water and cloth shaders.
- [x] Build textured-color terrain, rocks, grass, trees, bridge and ruins; detailed articulated character meshes.

## Task 2: Integrate and animate
- [x] Replace battle slab with terrain scene, thin tactical overlays, procedural props and improved characters.
- [x] Share revised materials and vegetation with world; add wind, pennants and grey-tide boundary.
- [x] Verify picking, shrinking and repeated rebuilds with art/UI tests.

## Task 3: Visual iteration and delivery
- [x] Run full suite, render native screenshots and inspect each.
- [x] Iterate lighting, composition and clarity against actual screenshots.
- [x] Update README and execution record; commit local work and open game.
