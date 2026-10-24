# Equipment Slots Implementation Plan

**Goal:** Replace verbose equipment list with icon slots, type-filtered choices and confirmed changes.
**Architecture:** Delegate equipment page to a dedicated Godot UI helper. Reuse campaign stat previews and mutations; keep selection and confirmation separate from committing changes.
**Tech Stack:** Godot, GDScript, SVG icons.

1. Add integration test for slots, type filtering, cancellation, replacement and removal confirmation.
2. Build vertical icon slots, current stats and tooltips; retain relic binding rules.
3. Add confirmation showing all stat deltas, adaptation, hero aura and previous owner impact.
4. Run equipment and character UI regression tests; render and inspect at 1280×832.
