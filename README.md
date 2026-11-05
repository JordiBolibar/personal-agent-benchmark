# Personal agent benchmark — results

This repo collects benchmarks of personal coding agents. More models can be
added later as new phases.

First edition — Mistral Large 4 vs GLM 5.3. Date: 2026-11-03 to 2026-11-05.
Both models at maximum thinking effort
(GLM 5.3 `thinking=max`, ML4 `thinking=high`, its only non-off level),
headless one-shot runs (`vibe -p --max-turns 1`, no tools), identical prompts,
temperature 1.0 for both during the runs. Speed = output tokens (reasoning
included) / generation time, from each run's API usage and timestamps.

Two phases:

1. **phase1-speed** — one self-contained Julia task (2D heat equation), 1
   warmup + 5 measured runs per model, interleaved. Full writeup in
   `phase1-speed/RESULTS.md`, independent method review in
   `phase1-speed/method-review.md`.
2. **phase2-varied** — 8 varied tasks (2 math, 2 Julia/SciML code, 2 glaciology
   theory, 2 ODINN-ecosystem) designed by a Claude Opus 5.5 (high) agent,
   run on both models, then graded by the same Opus agent. Tasks in
   `phase2-varied/tasks/`, per-run metrics in `phase2-varied/metrics.txt`,
   the Opus review in `phase2-varied/opus-review.md`.

## Phase 1 — speed on a single coding task

| metric | GLM 5.3 | Mistral Large 4 |
|---|---|---|
| valid runs | 5 | 4 (one 2.5 h server hang excluded) |
| median output speed | **145.5 tok/s** (101–174) | **58.1 tok/s** (7–86) |
| median wall time per task | 96 s | 28 s |
| total output tokens | 74,876 | 7,391 |

Per generated token GLM 5.3 is ~2.5x faster. Per task, ML4 finished sooner
because it wrote ~10x fewer tokens (mostly less hidden reasoning). Both models
solved the task correctly in every run — same quality, different length.

## Phase 2 — varied tasks (Opus-designed, Opus-graded)

Output speed per task (tok/s, median of finished runs):

| task | category | GLM 5.3 | ML4 |
|---|---|---|---|
| T1 | math: SIA adjoint derivation | 145.2 | 82.2 |
| T2 | math: SIA linearization + stability | 222.0 | 129.3 |
| T3 | Julia/SciML: rrule for tridiagonal solve | 219.9 | 84.9 |
| T4 | Julia/SciML: debug Lux/AD training snippet | 193.3 | 111.0 |
| T5 | glaciology: slab velocity + sliding | 234.0 | 103.4 |
| T6 | glaciology: response time scales | 166.6 | 94.8 |
| T7 | ODINN: UDE design for 10 glaciers | 122.5 | 55.9 |
| T8 | ODINN: manual SIA2D VJP debugging | 239.7 | 89.5 |

GLM 5.3 was faster per token on **every** task (median 206.6 vs 94.8 tok/s),
but ML4 used ~30% less total wall time because it writes about 3x fewer
tokens per answer.

Opus quality scores (1–5 per task, correctness + domain accuracy + completeness):

| task | ML4 | GLM 5.3 |
|---|---|---|
| T1 | 3 | 4 |
| T2 | 3 | 5 |
| T3 | 4 | 5 |
| T4 | 2 | 4 |
| T5 | 4 | 5 |
| T6 | 3 | 4 |
| T7 | 3 | 4 |
| T8 | 5 | 5 |
| **total** | **27/40** | **36/40** |

Opus verdict (full text in `phase2-varied/opus-review.md`): **use GLM 5.3 as the
default worker for ODINN.jl / SciML / glaciology tasks; use ML4 as a cheaper
second opinion on derivations.** Main dangers found: ML4's T4 "fix" still
crashes (Zygote mutation) and it used a wrong Γ in T2; GLM 5.3's serious error
is a wrong `@ignore_derivatives` use on the frozen mass-balance model in T7,
which would give a silently wrong gradient. With either model, check API names
and AD fixes against the source plus a gradient test before trusting them.

Caveats: most tasks have one graded answer per model (T1 has two for ML4);
Opus graded by hand without running code; two task wordings were flawed (T2's Γ,
T7's DiscreteVJP note).

## Repo layout

```
├── README.md                  <- this summary
├── phase1-speed/              <- phase 1: RESULTS.md, method review, prompt, answers/
├── phase2-varied/             <- phase 2: tasks/, metrics.txt, opus-review.md, answers/
├── harness/                   <- the scripts that ran and analyzed both phases
└── data/                      <- raw per-run metrics (phase1_runs.tsv, phase2_all_runs.jsonl, phase2_timing.log)
```

Answers are the final assistant text of each run (reasoning tokens are counted
in the metrics but not stored). No API keys or raw session exports are included.
