# Relic discovery implementation plan

Goal: Reveal relics only after encounters and add discovery milestones at 1, 10, 100 and the full catalog.
Architecture: Keep permanent discovered IDs in a separate atomic profile and in campaign saves. Merge profiles, saved discoveries, owned relics and displayed rewards on load. Catalog browsing never discovers relics. Milestones derive from unique valid IDs and grant no combat bonuses.
Tech stack: Godot GDScript.

1. Add failing discovery regression coverage for fresh profiles, deduplication, invalid IDs, persistence and milestones.
2. Add campaign discovery persistence and acquisition/reward encounter hooks; migrate owned relics from older saves.
3. Hide unseen catalog entries, record visible shop relics and show discovery achievement progress.
4. Run focused suites, full verification and native visual inspection. Preserve existing unrelated workspace changes.
