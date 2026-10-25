# Visual Skill Tree Implementation Plan

**Goal:** Replace the vertical skill list with a selectable profession tree and adjacent details.
**Architecture:** Profession definitions remain the source of nodes and prerequisites. A dedicated Godot control draws connections and presents clickable skill nodes, job tabs for the hero, and one selected-skill inspector. Character-specific ranks and XP remain in campaign data. Same profession shares the same tree; different professions use their own skills. Existing rules and unrelated pending changes stay intact.
**Tech Stack:** Godot Control, GDScript, existing scene tests.

1. Extend progression UI tests for node selection without spending, prerequisite protection, upgrade refresh, branch unlock, hero profession switching, and independent character ranks. Run and observe missing-tree failure.
2. Add game/skill_tree.gd for profession tabs, connected tree canvas, node status and selected skill inspector. Integrate into party_details.gd, preserving current skills and books below.
3. Run progression and character UI suites and full verification. Capture and inspect the actual game at 1280x832, fixing clipping or interaction issues.
