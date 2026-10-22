# Prototype execution ledger

User authorized autonomous implementation and iteration; no routine approval pauses.
Ruling: fresh empty project is already isolated; no existing branch to protect. Implement here, keep all tools local in ignored .tools.
Ruling: Godot selected for native 3D and future desktop/iOS export; install project-local official binary.
Preflight: tactical unit dictionaries are shared with campaign; copy into battles, reconcile after resolution. UI only calls validated public actions.
Task 1: in progress.

Task 1: complete — hex grid, speed turns, AP, HP/MP rest, attacks/skills, AI, deadline, shrinking, hero death.
Task 2: complete — persistent injuries/deaths, reserve survival, encounter lockouts, rewards, extraction, snapshots and validated atomic saves.
Task 3: complete — native 3D world and battle, deployment, reward/extraction/game-over panels, mouse picking, local launcher and README.
Review: independent read-only reviewer found screenshot/tests could overwrite real saves; fixed using injectable save destination and isolated capture/test saves. Also fixed capture battle phase normalization.
Ruling: first deadline test expected ordinary defeat with deployed hero; corrected expectation to gameover to match accepted rules.
Iteration: header layout failed scene test, fixed wrapping. Enemy model picking failed scene test, fixed projected model targeting. Save destination/schema test failed before fix, now green. Deep battle length failed initial target, strengthened enemy scaling; now reaches round 6 and two shrinks.
Visual verification: native rendered world and battle PNGs inspected; fixed header occlusion, thick health bars, CJK missing glyphs and excessive lighting.
Final verification: python3 tests/verify.py — 80 checks in six suites, zero failures; SCENE_SMOKE_OK. Native captures have no script errors.
Integration: retain local prototype branch in this fresh repository; no remote or merge base exists. No platform publishing performed.
Limitations: one small region, six starting units, no full recruitment/story/equipment-management system, simple models, no final audio/animation or phone layout validation.
