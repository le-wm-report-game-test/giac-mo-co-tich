# Godogen vs Manual Workflow

Decision matrix for "do I run Godogen, or build manually?"

## Choose Godogen when

- Project is brand new with no existing code
- You have a one-paragraph description and want a playable prototype in a few hours
- API budget allows Gemini/Grok/Tripo3D usage (~$50–$200 for a small game)
- C# is acceptable (Godogen generates C# only — see `gdscript-vs-csharp.md` in the upstream repo)
- Visual style is "stylized low-poly" or "2D pixel art" — Godogen's asset pipeline targets these
- You want automated visual QA loops (screenshot → critique → fix) without manual supervision

## Choose manual workflow when

- Existing GDScript project with established patterns (the case for `giac-mo-co-tich`)
- You need fine control over shader code, custom tools, or editor plugins
- The team's expertise is GDScript and switching to C# would slow them down
- API budget is zero or very tight
- The game requires a hand-crafted art direction that AI generators can't match
- You need to integrate with existing Git history and PR-based workflow

## Hybrid approach

For mid-life projects, consider a hybrid:
1. Use Godogen to **bootstrap new sub-systems** (e.g., a new enemy type, a new mini-game)
2. Pull the generated scenes/scripts into the existing project manually
3. Convert C# → GDScript if needed (mechanical work, but lossy on generic types)
4. Continue using `godot-4.7-game-dev` skill for ongoing edits

This works for:
- Adding a new boss fight mechanic to an existing game
- Prototyping a new gameplay mode
- Generating placeholder art while the art team works

## Time / cost comparison (small 2D platformer)

| Phase | Manual | Godogen |
|---|---|---|
| Project bootstrap (scene tree, scripts) | 4–8 hours | 30 min |
| Asset generation (sprites, tilesets) | 2–5 days (artist) | 1–2 hours + API cost |
| Visual QA iterations | Manual review per change | Automated, ~20 cycles/hour |
| Total wall time | 1–2 weeks | 1 day |
| Total cost | Dev time only | Dev time + ~$50 API |

## Visual QA loop anatomy

Godogen's loop is reproducible manually:

```bash
# 1. Capture screenshot
godot --headless --path . --script res://src/tests/screenshot_tool.gd
# → user://screenshot.png

# 2. Critique (manual or via vision-capable agent)
#    "Does this match the design brief? Check for: z-fighting, missing textures, broken proportions"

# 3. Fix based on critique
# Edit scenes/materials/scripts

# 4. Re-capture and re-critique
# Repeat until acceptable
```

The automation comes from packaging this as a Claude/Codex agent that runs the loop unattended.

## What Godogen does NOT do well

- **Narrative-heavy games.** Dialog trees, branching stories — AI asset pipeline doesn't help.
- **Multiplayer networking.** Out of scope; needs hand-rolled RPC layer.
- **Performance-critical systems.** AI-generated code optimizes for correctness, not frame budget.
- **Localization.** Generated strings are English-only.
- **Accessibility features.** Color-blind modes, audio cues — must be added manually.