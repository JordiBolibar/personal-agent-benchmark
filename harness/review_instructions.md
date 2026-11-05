# Reviewer brief — model benchmark on ODINN.jl / SciML / glaciology tasks

You designed the task set below (T1-T8) for a benchmark. The tasks were run
headless, single turn, no tools, maximum thinking effort, on two models:
`mistral-large-4` (ML4) and `glm-5-3` (GLM 5.3). Each task was run twice per
model (runs r1 and r2). Below each task you get both models' answers for both
runs, with the measured speed of each run.

Your job: grade the answers. Reply in ONE message, no tools, plain markdown.

1. Per task and per model, check:
   - Correctness: is the math / code actually right? Check derivations line by
     line where you can: adjoint signs, terminal and boundary conditions (T1);
     amplification factor and exact stability bounds (T2); the rrule pullback,
     signs and O(N) claims (T3); the defect list and corrected code (T4);
     velocity profile, flux, diffusivity and the numbers in parts B/C (T5);
     response vs kinematic vs diffusive time scales and the sign of the bias
     (T6); API accuracy for ODINN (targets, losses, VJP types, UDEparameters
     settings) and honesty about uncertainty instead of invented keywords (T7);
     the VJP derivation, the error list and the fix (T8).
   - Domain accuracy: glaciology and SciML specifics (SIA, Glen's law,
     staggered grids, AD through solvers, adjoint methods).
   - Completeness: did the answer cover every numbered part of the task?
   - Notable errors, ranked. If a model invented an API name, flag it.
2. Give a score 1-5 per model per task (5 = fully correct, complete, no
   invented APIs).
3. Output format:
   a. A markdown table: rows = tasks T1-T8, columns = ML4 score, GLM 5.3
      score, plus one short note per task on the deciding factor.
   b. A bullet list of the most important errors made by each model.
   c. Note any case where the two runs (r1 vs r2) of the same model disagree
      in correctness.
   d. An overall verdict: on ODINN.jl / SciML / glaciology work like the user's,
      which model is more reliable, and where does each one fail? Consider the
      measured speed too (given per run and summarized at the end).
