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

## 2026-10-24 character and combat presentation
- Researched official Quaternius and KayKit assets; imported four CC0 KayKit 1.0 GLB templates with 75 clips each, original license and checksums. Six party roles use the templates with appropriate weapons; enemy archer uses ranged model/motion.
- Added locked anticipation/impact/recovery presentation for player and enemy commands, legal-path movement, melee/ranged/cast animations, projectiles, hit/death, HP/MP rest, actual floating deltas and restoration particles. Final results resolve after playback. Rules and save format remain intact.
- Replaced solid ball tree crowns with instanced leaf geometry; native attack/rest screenshots inspected.
- Ruling: complete CC0 cartoon pack is a provisional asset integration, not final natural-proportion art. This prioritizes working rigs and readable battle actions; cost is a more cartoon-like silhouette than the requested reference until new characters are selected.
- Regression evidence: initial presentation test failed because timeline and skeletal animation were absent. Independent reviewer found a script indentation error, movement shrink feedback disappearing in its creation frame, and enemy archer using sword motion. Fixed syntax; added movement-recovery and enemy-archer regressions, observed three failures then green after fixes. Differentiated enemy material tint.
- Final: python3 tests/verify.py — 109 checks in 8 suites, zero failures; native scene smoke passed. Native battle, attack and rest captures rendered without script errors.
- Remaining: final natural-proportion character production, varied enemy art, sound, polished skill-specific choreography, mobile performance and release builds. No purchase, publication or asset claims of matching Zelda quality.

## 2026-10-24 natural-proportion lineup iteration
- Ruling: use the complete Quaternius RPG Character Pack instead of bare Universal Base Characters. Existing fantasy clothing and native sword/dagger/bow/spell clips avoid a clothing/retargeting dependency. Cost: fewer distinct base models and a stylized low-poly finish; custom final models remain future work.
- Imported original CC0 Warrior/Rogue/Ranger/Cleric glTF files from author's public linked Drive folder; recorded source, license and checksums. Replaced displayed lineup, kept earlier KayKit source assets.
- Character suite initially showed 23 missing-backend/effect/archer failures; now all 122 checks pass. Logical animation API maps to imported native clips, including hit/death and pickup recovery gestures. Added temporary rest posture and role-specific slash, arrow, magic and healing projectiles. Lethal timeline now accommodates the entire new Death clip.
- Ruling: rest uses a recovery gesture plus posture and particles because this source pack has no dedicated sitting clip. Cost: less literal resting choreography until custom or retargeted rest motion is added.
- Native battle/attack/rest captures inspected for silhouette, materials, orientation, effects and labels. Adjusted diffuse/rim shading and forward-axis offset.
- Discovered battle redraw reset user zoom. UI regression failed before fix, then passed; initialize camera zoom only at battle entry, preserve through actions and mode changes.
- Independent reviewer found no blocking defects, verified a clean-cache import and 122 character checks; documentation synchronization completed.
- Final verification: 233 checks in 9 suites passed, plus native scene smoke passed. Character models, effects and camera only; battle/save rules preserved.

## 2026-10-24 original costume layers and staged skills
- Added original torso-bound curved cloth, shoulder wraps, clasps, engineer satchel and role palettes; pinned-edge wind and soft texture-preserving character light bands. Source glTF and textures unchanged.
- Corrected the previous forward-axis assumption using a native two-sided model comparison. Added head-bound eyes and brows; Cleric uses Head_2 and an original visible face surface rather than its stone-like outer helmet.
- Ruling: keep existing licensed rigs, add original secondary costume geometry and shaders instead of another pack swap. Cost: original base silhouettes/hair and shared templates remain recognizable, and cloth is procedural rather than simulated.
- Skills now draw/prepare, gather restrained motes and ground wind ring, release, impact, recover; projectiles stay hidden before release. Normal attacks remain faster. Full death clips and once-only impacts are retained.
- Initial regression failures: no wardrobe on six allies; no bow-draw or hidden charge projectile. Green after implementation. Independent review found wrong projectile destination when skill-ending shrink damages another actor, and Cleric head-bone mismatch. Added failing regressions and fixed by explicit target ID and Head_2 fallback.
- Captured and inspected native six-role lineup plus skill charge/release. A capture helper uses isolated campaign data; no real save changes. Shared workspace concurrently contains menu/equipment work; kept that work intact.
- Scope limits: no custom full-body sculpt, new facial rig, or physics cloth; this is a further original stylized prototype refinement, not reference-game production parity.
- Final follow-up verification: 402 checks across 14 current workspace suites passed, including 139 character checks and 29 presentation checks; native scene smoke passed. Native lineup confirms Cleric face visible after Head_2 fix. Original costume and staged-skill changes were retained alongside concurrent menu/route/equipment work.
