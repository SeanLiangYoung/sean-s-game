# Overall difficulty

Four campaign difficulties: 普通, 困难, 噩梦, 我想找死. Existing saves default to 普通. Hard now applies +25% enemy maximum HP and +15% enemy power to the corresponding normal encounter, rounded to integers after regional growth and enemy affixes. Nightmare adds the same +25% HP and +15% power step on top of the rounded hard values (approximately +56% HP and +32% power versus normal). The final difficulty applies +50% HP and +25% power on top of nightmare (approximately +134% HP and +65% power versus normal). Normal is unchanged. Six-region progression continues to apply.

Defeating the final boss completes a difficulty and unlocks the next difficulty. Unlocks persist locally in a separate progression file alongside display preferences, so replacing the campaign save does not erase them. The campaign save and expedition recovery snapshot retain the chosen difficulty.

Choose an unlocked difficulty alongside the captain when starting a new campaign. Settings show the current difficulty; locked options explain which difficulty must be completed. The atlas distinguishes overall difficulty from region progression. Final rewards announce the next unlock.

Validation: menu tests cover selection, sequential unlocks, persistence, existing save migration and invalid difficulty values; the existing full verification suite checks battle balance, campaign recovery and finale behavior.

## Captain unlocks

Shen is available initially. Wen requires clearing normal (unlocked difficulty rank >= 1); Lu requires clearing nightmare (rank >= 3). Reuse the local difficulty unlock record. Locked captain buttons show their conditions, direct starts are guarded, and invalid or locked selections fall back to Shen. Continuing existing saves remains allowed. Final rewards announce the captain unlocked by the completed difficulty.

Character identity UI tests cover initial locks, guarded starts, each completion milestone, persistence, and continuing an existing Lu save without the local unlock file.

## Hard difficulty implementation

The saved campaign difficulty is forwarded through a shared battle configuration used by combat and enemy previews. Rank 1 applies one scaling step; rank 2 applies two successive steps; rank 3 applies three successive steps. Enemy count, armor, speed, range, battlefield generation and player stats retain normal behavior. Legacy encounters remain legacy encounters when their only configuration field is overall difficulty. Existing saves retain their difficulty on load and expedition recovery.

Tests compare baseline enemies against all four difficulties across six regions, three threats, three encounter tiers, two region ranks and two seeds. They also cover campaign forwarding, preview consistency and prebattle save reloads for both generated and legacy encounters.

## Nightmare difficulty

Nightmare applies a second +25% enemy HP and +15% enemy power step to the already rounded hard stats, including base enemy power. This affects normal enemies, elites and bosses without modifying player stats, terrain, enemy count, armor, speed or range. Existing preview and saved difficulty forwarding are reused. The final difficulty adds a stronger third step to nightmare as described below.

The difficulty regression suite verifies nightmare against hard values across all existing region/threat/tier/rank/seed combinations, plus preview and prebattle-save consistency.

## Final difficulty

我想找死 applies a third +50% enemy maximum HP and +25% power step to the rounded nightmare stats, including base enemy power. Normal, hard and nightmare retain their existing behavior. All regions and threats use the same rule; previews and saved campaign difficulty continue through the shared battle configuration.

Tests explicitly compare final-difficulty enemies to their nightmare equivalents, check unchanged player stats and battlefield layout, and verify preview and save consistency at every difficulty.
