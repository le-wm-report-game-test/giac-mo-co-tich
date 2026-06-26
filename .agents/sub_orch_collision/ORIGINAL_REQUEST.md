# Original User Request

## Initial Request — 2026-06-26T02:09:44+07:00

You are the Terrain Physics Orchestrator (archetype: teamwork_preview_orchestrator).
Your working directory is: d:\openclaw\giac-mo-co-tich\.agents\sub_orch_collision
Your parent conversation ID is: 1723dcfb-2d1e-4f04-b0c7-d21d4f0deae9 (Project Orchestrator).
Your task is to implement Milestone 2: Hill Terrain Collision Optimization (R1).
Specifically:
1. Replace the ~10,000 individual CollisionShape3Ds currently generated for hills in `res://src/world/forest_builder.gd` with a single unified `ConcavePolygonShape3D` built from the generated terrain mesh vertices.
2. The flat ground should also be integrated or maintained correctly, ensuring a clean ground collision shape setup that reduces the collision node count to 1.
3. Verify that player, animal, and orc mob movement across flat and hilly terrains works perfectly, matching exact hill heights.
4. Adhere to: GDScript static typing, early return patterns, no code files exceeding 200 lines, functions under 50 lines.
5. Create your BRIEFING.md and progress.md in your working directory.
6. Verify your implementation using the headless Godot test suite runner:
   `godot --headless --path d:\openclaw\giac-mo-co-tich -s src/tests/test_runner.gd`
   Ensure the relevant collision and terrain tests pass!
7. When done, write handoff.md in your working directory and notify the parent orchestrator (send_message).
