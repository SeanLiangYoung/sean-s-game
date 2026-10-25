# Village, Story and Relic Strategy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Track completed work here and in delivery notes.

**Goal:** Deliver one integrated playable iteration of the user's visual, story and relic strategy direction.
**Architecture:** Separate story/state, village geometry/UI and relic advice into focused scripts; integrate through existing campaign and main UI. Preserve accepted combat and reward RNG.
**Tech Stack:** Godot 4.7.2, procedural 3D, GDScript, existing Python verification runner.
**Spec:** docs/superpowers/specs/2026-10-25-village-story-relics-design.md

## Global Constraints
- Gray tide is a natural phenomenon, affecting both floating rock and ground; no omniscient reveal.
- Preserve houses of dead residents and companion casualties.
- Keep original numerical difficulty and loot RNG unchanged.
- Native horizontal layout, existing saves migrate, all new state validated atomically.
- User authorizes continued implementation and internal iteration; final user review follows working delivery.

## Review Focus
- Legacy/corrupt save story state: atomic rejection or migration.
- Duplicate node visit/load/snapshot: no repeat grants or inconsistent discoveries.
- Personal relic binding/replacement/exhaustion: actual per-actor resonance only.
- Returning from combat/menus/maps: village remains accessible and no stale overlay.
- Small viewport and long Chinese text: actions visible, details scroll, no story spoilers in locked content.

### Task 1: Story and village persistence
**Files:** game/village_story.gd (new), game/campaign.gd, tests/village_story.gd (new).
**Interfaces:** VillageStory.initial_state(), valid_state(), fragment(id), available_home_fragment(state, home, expedition), route_fragment(region, depth, boss); campaign.read_home(id), repair_home(id), record_route_story(boss), story_state.
- [x] Write tests for legacy migration, valid/invalid atomic saves, repeat interactions, region progression, repair limits and snapshot rollback.
- [x] Run headless tests, observe missing behavior fail.
- [x] Implement bounded persistent state and hooks; preserve original resources and RNG.
- [x] Run story tests and original persistence/route tests.

### Task 2: Village visuals and exploration
**Files:** game/village_art.gd, game/village_ui.gd (new), game/atlas.gd, game/main.gd, tests/village_ui.gd, tests/village_render.gd (new).
**Interfaces:** VillageArt.build(host), VillageUI.render(host, atlas), home(host,id), journal(host).
- [x] Test village-to-map-to-route flow, home/journal controls, dead homes, opening, and return navigation.
- [x] Build colored weathered homes, roofs, paths, coastal tundra, warm windows, floating rock silhouette and repairs.
- [x] Wire home exploration, short opening, route discoveries and journal with existing modal/detail controls.
- [x] Render real screenshots at 1280×800 and 1024×640, inspect and iterate.

### Task 3: Relic decisions
**Files:** game/relic_strategy.gd (new), game/main.gd, game/management_ui.gd, tests/relic_strategy.gd (new).
**Interfaces:** RelicStrategy.applicable(entries,owner), compare(entries,id,owner), overview(entries,roster), lore(id).
- [x] Write threshold, owner replacement, exhausted/duplicate relic and no-mutation tests; observe fail.
- [x] Implement per-actor comparisons and actionable advice for all eight themes without changing combat.
- [x] Add reward and binding previews, held-build page and restrained relic provenance.
- [x] Run strategic tests, relevant UI tests and native captures.

### Task 4: Integrated review and delivery
**Files:** tests/verify.py, docs/playtest/2026-10-25-village-story-relics-delivery.md, artifacts/village-*.
- [x] Run full existing verification and new suites; fix failures and repeat affected checks.
- [x] Run native scripted journey covering village, region, story, reward, extraction, repair and save/load.
- [x] Review whole change and screenshots, iterate on findings, rerun impacted validation.
- [x] Commit reviewable changes on codex/village-story-relics; provide exact tested scope and remaining limits.
