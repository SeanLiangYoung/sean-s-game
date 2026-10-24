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

## 2026-10-24 art upgrade
Standing authorization used to execute approved Tears-of-the-Kingdom-inspired original style without routine confirmation. Added separate Art factory and painterly, wind, water, cloth and tide shaders. No simulation/save-format changes.
Art test initially failed (missing factory), then passed after integration; now 10 visual/state checks. Fixed overbright custom diffuse lighting against Godot shader reference (LIGHT_COLOR includes PI), ring/cylinder orientation mismatch, water stepping, grass in water/paths, cape flutter axis and status contrast after native screenshot review.
Independent read-only review reported no blocking defects. Native Compatibility captures inspected for world, battle, warning and post-shrink terrain. Full suite expanded to 90 checks / 7 suites plus native scene smoke.
Ruling: scenery outside the tactical field may have height; tactical picking and actor positions stay on the existing plane. Shared generated assets used across encounter types, with broken bridge as the main sample.
Limits: procedural original art is an intermediate visual sample; no final rigged battle animations, no measured mobile performance, no assertion of matching reference game's production quality.
