# Equipment Appearance Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans and test-driven-development.

**Goal:** Weapons, shields and armor visibly follow equipped inventory in battlefield models and every portrait.

**Architecture:** Campaign exposes a canonical appearance profile (stable appearance identity plus three equipped item IDs). Character visuals consume this profile for bone-mounted attachments; portrait caching uses the same profile. Keep faces, hair and character identity independent of profession and equipment.

**Tech Stack:** Existing Godot skeletal characters, reusable CC0 weapon meshes, original procedural crossbow/shield/armor; no new downloads or image generation.

**Spec:** User request on 2026-10-24: switching weapons, shields and armor changes battlefield models and portraits.

## Global Constraints

- Do not modify combat balance, slot rules, profession or save schema.
- Reuse existing human models; their integrated underclothes remain, with distinct leather and plate armor fitted above them. No full-body replacement that changes the person's identity.
- Native sword/dagger/bow/staff meshes attach to the weapon bone. Crossbow and shield are original geometry; armor follows torso/arm/leg bones.
- Import compatible skeletal weapon actions so a new weapon's action/effects no longer depend on profession or character ID.
- Profile-aware portraits show enough torso, hands and shoulder armor to distinguish gear; reuse texture when unchanged and release obsolete portrait viewports when changed.

## Review Focus

- Empty slots must remove original baked-in hand gear and restore clothes when armor is removed.
- Transferring equipment must update both owners' models and cached portraits.
- All character rigs must accept all weapon categories without missing animation tracks or changing the face.
- Every small equipment change must be visible in actual rendered portrait pixels, not only a cache key.
- Reload and newly recruited characters must derive the same profile without persisting visual objects.

### Task 1: Canonical profiles and visual attachments

Files: `game/campaign.gd`, `game/equipment_visual.gd` (new), `game/character_visual.gd`, `tests/equipment_visual.gd` (new).

Interfaces: Campaign `visual_profile(id) -> Dictionary`; Visual `create(parent,kind,profile={})`, `apply_loadout(pawn,profile)`. Profile keys: appearance, mainhand, offhand, armor. Cache signature is determined by these keys alone.

- [x] Write and run failing tests for profile transfer, bone-mounted gear, native weapon hiding, removing plate and cross-profession attacks.
- [x] Implement pure inventory profiles, original fitted armor and shield, cached reusable weapon mesh resources, compatible animation libraries and weapon-based effects/actions.
- [x] Run attachment and existing character/presentation tests.

### Task 2: Shared portrait and scene integration

Files: `game/portraits.gd`, `game/art.gd`, `game/main.gd`, `tests/equipment_appearance_ui.gd` (new).

Interfaces: `portrait(id,profile={}) -> Texture2D`, profile-aware Art.character and Main.make_pawn. UI obtains profiles from campaign, no per-panel inferred equipment.

- [x] Write and run failing tests for changed portrait texture, stable unchanged cache, bounded viewport count, and real UI gear transfer.
- [x] Apply profiles to battlefield/world actors and all card/detail/deployment portraits; refresh existing world pawn when equipment changes.
- [x] Render all five weapons, shield and both armor styles on multiple people; inspect portraits and compare pixels.
- [x] Run full verification, fresh independent review, fix substantive findings, document and commit only this task's changes.

## Decisions

The user's explicit implementation request authorizes this continuation. Use the existing working branch and retain preexisting artwork changes. Equipment silhouettes and materials follow the current stylized art; no new art pipeline or profession redesign.


## Implementation ledger

Task 1: complete — canonical inventory profile; all six original rigs accept five weapon types, shield, leather and plate; mesh resources reused; original weapons hidden; armor removal restores original accessories; weapon animations retarget shared bone names.
Task 2: complete — all card/detail/deployment portraits and live world/battle pawns use the same profile; cache retains one render per character; native rendered lineups/dossier/battle inspected.

Ruling: reuse compatible bow release motion for the crossbow, with a distinct animation name; no new animation asset dependency.
Ruling: freeze cloth shader motion in static portraits only, because actual render comparison exposed small wind-phase differences when returning to the same outfit.
Independent review: stationary world pawn could keep its previous weapon idle; regression reproduced, then fixed loadout application to replay the current idle or walking action only when the profile changes.

Final verification: `python3 tests/verify.py` passed 806 checks across 20 suites, including native portrait pixel comparisons and scene smoke; no script errors. `git diff --check` passed. Screenshots inspected: equipment-appearance-lineup.png, equipment-dossier.png, equipment-battle.png.
