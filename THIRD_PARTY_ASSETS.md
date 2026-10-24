# Third-party assets

## KayKit Adventurers Character Pack 1.0

- Author: Kay Lousberg / KayKit Game Assets.
- Source: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0
- Official product: https://kaylousberg.itch.io/kaykit-adventurers (current release is 2.0; this project uses the official GitHub 1.0 release).
- License: CC0 1.0. Original license retained at `assets/characters/kaykit/LICENSE.txt`.
- Imported 2026-10-24: Knight, Barbarian, Rogue, Mage GLB files with embedded textures and 75 animation clips each. External texture copies retained for editing. Checksums in `assets/characters/kaykit/SHA256SUMS`.
- Local customization: role-to-model mapping, visible weapon selection, scale, roughness and animation playback. Source models are unmodified.
- Provisional art direction: these are stylized cartoon characters, not final natural-proportion characters and not Zelda assets. No Nintendo or Square Enix assets are used.

## Further evaluated sources (not included)

- https://quaternius.com/packs/universalbasecharacters.html — CC0 humanoid bases, 13k triangles on average, requires clothing and motion integration for this game's roles.
- The complete RPG pack evaluated here was subsequently adopted; see Active lineup below.

Terrain, shader effects, UI and combat feedback code are project-authored.

## Active lineup: Quaternius RPG Character Pack

- Author: Quaternius.
- Official product/license: https://quaternius.com/packs/rpgcharacters.html — CC0 1.0, personal and commercial use.
- Official download folder linked by author: https://drive.google.com/drive/folders/1MIRQXLfTd21HMI5rwOb6Xy0rv0xv1m8b
- Files: original Warrior.gltf, Ranger.gltf, Rogue.gltf, Cleric.gltf from its glTF folder. Embedded geometry, textures, rig and native role animations. Downloaded 2026-10-24.
- Source files unchanged; SHA256SUMS records provenance. Godot extracts PNG copies on import. Local presentation changes are runtime scale, tint, diffuse/rim material settings and action-to-clip mapping.
- This pack replaces the displayed KayKit lineup. KayKit files remain available as earlier prototype assets.
- Rest animation uses the pack's PickUp recovery gesture (Cleric Spell1), with a temporary lowered posture and recovery effects; this pack has no dedicated sitting-rest clip.
- Bases and animations remain stylized low-poly; this is an iterative prototype upgrade rather than final custom character production.

## Original additions to character presentation

Curved travel cloth, shoulder wraps, clasps, satchel details, head-bound facial details, material shaders, wind and staged skill effects are project-authored geometry/code. They are runtime additions; original Quaternius glTF and embedded source textures remain unchanged. Cloth motion is procedural with pinned tops, not physical cloth simulation.
