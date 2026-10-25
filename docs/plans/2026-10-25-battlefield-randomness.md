# Moderate Battlefield Randomness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Vary tactical routes and deployment while preserving connected, shrink-safe battlefields.

**Architecture:** Add a deterministic battlefield generator invoked only for configured encounters. Keep radius, combat and late shrink capacity rules unchanged. Reserve the central seven cells, validate all open cells at every radius, and reject placements that block deployment exits. Derive an independent RNG from encounter seed so enemy generation remains stable.

**Tech Stack:** Godot 4 GDScript, native SceneTree regression suites.

### Task 1: Regression specification
- Create `tests/battlefield_generation.gd`: sample all six biomes, seeds and party sizes; verify deterministic layouts, deployment variation, regional density, connectivity for radii 1–4, central clearance, spawn separation/exits and actual shrink evacuation.
- Run the new suite against current code and confirm failures for insufficient terrain/deployment variation.

### Task 2: Generator
- Create `game/battlefield.gd` with four weighted obstacle structures, rotated deployments, bounded density, connectivity validation and safe placement checks.
- Replace only the configured-encounter obstacle block in `game/rules.gd`; preserve legacy encounters and all existing working-tree work.
- Run the new suite and existing expedition generation/balance suites.

### Task 3: Integration verification
- Register suite in `tests/verify.py`, document behavior in `README.md`.
- Run `python3 tests/verify.py`, repair any regressions, inspect final patch. No commit or external publication requested.
