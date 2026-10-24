# Eighteen Characters Implementation Plan

**Goal:** Add the approved eighteen biographies and talents, three starting captains, recruitment and character details.
**Architecture:** A canonical character catalog owns identity and prose; a talent module supplies combat hooks. Runtime actor ID `hero` remains the captain regardless of selected identity. Save version 7 validates character identities and migrates legacy saves without resetting progression.
**Tech Stack:** Godot / GDScript.
**Spec:** User-approved eighteen-character proposal in this conversation.

## Constraints and decisions
- Keep all existing workspace edits; work in place because dependent uncommitted game systems are already here.
- New games start with one chosen captain and one representative of each other profession. All fifteen mercenaries are available at recruitment nodes; existing ten-person capacity remains.
- Legacy character names, IDs, stats and equipment remain; assign canonical identities through legacy ID/name mapping, with class fallback for historical hires.
- Stronger talent shields replace weaker shields and preserve their existing source/expiry if replacement is unnecessary. Support healing follows recipient recovery modifiers as existing healing does.
- Qin Zheng's interrupt reward applies to the existing interruptible overload, cancelling it immediately; other boss attacks retain their existing counter rules.

## Tasks
- [x] Catalog and persistence: add catalog tests (18, 3/job, valid skill/relic references), starting captain selection, unique recruitment, version 7 validation and old-save migration.
- [x] Combat: add behavior tests for all eighteen talents, costs/ranges, movement, support shields, marks, guard caps, refund caps and expiry; implement hooks outside the main rule flow where possible.
- [x] UI: add captain selection before save creation, recruitment biographies/talents, details sections, dynamic costs/ranges; test selection/cancel/reload and all identity details.
- [x] Verify: run complete existing suite, native UI screenshots, inspect final diff and document behavior.

## Review focus
- Selection/cancellation must never overwrite a save prematurely.
- Identity validation must reject invalid/duplicate catalog IDs atomically, including nested snapshots.
- Talent temporary flags must reset per personal action and never persist in campaign data.
- Dead actors and unsuccessful healing must not generate support/refund rewards.
- Range/cost previews and automatic battle must use the same talent-aware checks as manual commands.

## Verification and review
- Character catalog: 97 checks; talents: 50 checks; identity/captain UI: 41 checks, all pass (188 total).
- Native screenshots inspected at 1280x800: captain selection and character details; talent placed before biography for visibility.
- Whole feature independently reviewed; no actionable correctness findings. Additional regression pins skill preview as read-only (no talent state written to campaign roster).
- Full verification reached an existing integration duration assertion failure after concurrent enemy-skills work appeared in the workspace. Remaining suites were run separately, including scene smoke and native rendering.
- Read-only four-way diagnostic (talents on/off, new enemy skills on/off) isolates that failure: enemy skills enabled loses at round 3 in either identity configuration; disabling those skills passes all 17 integration checks in either configuration. Kept concurrent enemy changes and the original integration assertion unchanged.

## Regression follow-up — 2026-10-25
The earlier enemy-skills diagnostic identified the change that exposed the failure, but the actual failure was an inaccurate test assumption: a lethal shrink at the end of round three exits before incrementing the round counter. The integration assertion now verifies the reduced radius and shrink event directly. `tests/edges.gd` additionally verifies round-three lethal shrink, observable tide state and no repeated transition after resolution. No combat balance or enemy skills were changed for this correction.

Complete validation: `python3 tests/verify.py` exited 0 with **61,604 checks across 53 suites**, plus scene smoke and native appearance/equipment preview rendering. `git diff --check` passed.
