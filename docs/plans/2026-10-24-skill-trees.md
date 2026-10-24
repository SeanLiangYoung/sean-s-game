# Experience skill trees implementation plan

**Goal:** Individual experience unlocks and strengthens profession skills; survivors share victory XP and killers receive bonus XP.
**Architecture:** Profession definitions own prerequisites, ranks and effect previews. Campaign owns spending, awards and migration. Rules record enemy kills and apply rank effects. Existing uncommitted UI work stays in place.
**Tech Stack:** Godot / GDScript.

1. Add failing progression tests for shared XP, kill bonuses, learning prerequisites, rank caps, migration and combat effects.
2. Add per-character XP and skill ranks, profession tree definitions, purchase validation and save version 3 migration.
3. Record player kills and apply rank bonuses to damage, healing, traps and support effects; settle XP only once on victory.
4. Render skill trees on the existing Skills page with prerequisites, costs, ranks and current/next effects. Keep legacy books usable.
5. Run progression tests and full existing suite; render and inspect the Skills page.

Initial tuning: victory pool 120/180/240 XP by encounter, evenly split with discarded remainder; +15 XP per enemy kill. Basic skill rank 1 free on first entering a profession; advanced unlock 30 XP, rank 2 costs 45, rank 3 costs 75. Advanced skills require the profession basic skill at rank 2. Hero may study every tree. No spending during battles or reward selection.
