---
name: godogen-pipeline
description: Godogen — AI pipeline that designs, codes, generates assets, and visually QA-tests a complete Godot 4 project from a game description. Use when bootstrapping a new Godot project from scratch or running visual-QA loops on an existing scene.
risk: external-services
source: synthesized
date_added: "2026-07-09"
target_version: "Godot 4.x"
---

# Godogen Pipeline

End-to-end AI game generator for Godot. Describe a game → AI designs architecture, writes GDScript (or C#), generates art via Gemini/Grok/Tripo3D, captures screenshots from the running engine, and fixes what doesn't look right.

**Source:** https://github.com/htdt/godogen (also `ssomPark/godogen` fork).

## Use this skill when

- Bootstrapping a brand-new Godot project from a one-paragraph game description
- Want AI-driven visual QA loops (screenshot → critique → fix)
- Need automated asset generation (textures, simple 3D meshes, animated sprites)
- Building a procedural game prototype quickly

## Do not use this skill when

- The project already exists and you only need to modify a few scripts (use `godot-4.7-game-dev`)
- No API keys for Gemini / xAI Grok / Tripo3D are available (asset generation will fall back to placeholders)
- You need to ship production code (Godogen output is C# only — Godot's GDScript tooling is more idiomatic for most Godot devs)
- Project requires custom shaders beyond basic StandardMaterial3D

## What Godogen produces

Output is a real Godot 4 project with:
- Properly organized scenes (one responsibility per scene)
- Strict static typing
- Working game architecture (composition over inheritance)
- Generated art assets (textures from Grok, 3D meshes from Tripo3D, animated sprites from Grok video)
- Visual QA loop: launches the game, screenshots, uses multimodal review to catch:
  - Z-fighting
  - Missing textures
  - Broken physics
  - Mismatched art styles
- Iterative fix loop until visual quality passes

## Publish a game repo

Godogen is itself a generator, not a game. Two flavors:

```bash
# Claude Code flavor — writes CLAUDE.md and .claude/skills/
git clone https://github.com/htdt/godogen.git
cd godogen
./claude/publish.sh ~/my-new-game

# Codex flavor — writes AGENTS.md and .agents/skills/
./codex/publish.sh ~/my-new-game
```

Then `cd ~/my-new-game` and start the host agent (Claude Code or Codex). The agent picks up the skills and runs the full pipeline inside that directory.

## Required tooling

```bash
# 1. Godot 4 on PATH
which godot  # or godot4

# 2. System packages (Linux)
sudo apt install -y vulkan-tools xvfb ffmpeg imagemagick

# 3. Python 3 + uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# 4. API keys for asset generation
export GEMINI_API_KEY=...
export XAI_API_KEY=...
export TRIPO3D_API_KEY=...
```

## Visual QA loop (the killer feature)

Godogen runs the game and asks a multimodal model: *"Does this screenshot match the design?"*. Failed checks (z-fighting, missing textures, broken proportions) loop back as fix tasks.

For an existing project, you can run the same pattern manually:

1. **Capture**: `godot --headless --path . --script res://src/tests/screenshot_tool.gd`
2. **Critique**: feed screenshot to a vision-capable model with the design brief
3. **Fix**: agent edits scene/material/code
4. **Re-capture**: confirm visually
5. **Repeat** until acceptable

## Differences from in-repo skills

| Concern | `godot-4.7-game-dev` | `godot-mcp` | `godogen-pipeline` |
|---|---|---|---|
| Project stage | Existing, mid-development | Existing, mid-development | Brand new or rebuild |
| Engine target | Godot 4.7 strict | Godot 4.x | Godot 4.x |
| Output code | GDScript | n/a (MCP, no codegen) | C# / .NET 9 |
| Asset pipeline | Manual | Manual | Automated (Gemini/Grok/Tripo3D) |
| Visual QA loop | Manual | Manual | Automated |
| Set up cost | None (skill only) | MCP server install | External API keys + publishing script |

## When NOT to use Godogen

- **Existing GDScript project.** Godogen regenerates from scratch; you lose all existing code.
- **C# blocked by team.** Most Godot teams prefer GDScript for faster iteration and tighter integration.
- **Custom shaders.** Godogen's asset pipeline targets StandardMaterial3D — ShaderMaterial work is post-Godogen.
- **No internet/API budget.** Each visual QA cycle costs API calls; large projects can run $50–$200.

## Pairing with this workspace

For `giac-mo-co-tich` (this repo):
- The project is mid-development — use `godot-4.7-game-dev` for edits, not Godogen
- For visual QA on lighting, the existing `src/tests/screenshot_tool.gd` is the same pattern Godogen automates
- For MCP scene introspection, set up `godot-mcp` — see companion skill

## Additional resources

- `resources/godogen-vs-manual.md` — when to choose Godogen over hand-rolled workflow
- `resources/asset-pipeline-options.md` — alternative art generators (Meshy, Scenario, Leonardo)
- Official repo: https://github.com/htdt/godogen