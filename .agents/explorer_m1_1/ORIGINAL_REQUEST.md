## 2026-06-25T17:39:09Z
You are Codebase Explorer 1. Your working directory is: d:\openclaw\giac-mo-co-tich\.agents\explorer_m1_1.
Your task is to refine the E2E testing design for Giac Mo Co Tich.
Read the initial report at `d:\openclaw\giac-mo-co-tich\.agents\explorer_e2e_tests_1\handoff.md` and the proposed scripts in that directory.
Then, design in detail:
1. The method-based E2E test runner that discovers all functions starting with "test_" in a test script, calls `setup()`, runs each test function (awaiting if it yields/returns a signal), and calls `teardown()`.
2. The specific test cases for:
   - Tier 1: Ground & Hill Terrain Collision, Boss Lifecycle (5 tests per feature).
   - Tier 2: Boundary/Edge cases for these two features (5 tests per feature).
3. Ensure no script exceeds 200 lines, and all methods are typed statically and keep under 50 lines.
4. Output your detailed design/blueprint to `d:\openclaw\giac-mo-co-tich\.agents\explorer_m1_1\design.md`. Do NOT modify any source files.
