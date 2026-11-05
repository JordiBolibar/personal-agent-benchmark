# Phase 3 — expanded task benchmark: ML4 vs GLM 5.3

Date: 2026-11-05. Models: `mistral-large-4` (ML4) and `glm-5-3` (GLM),
both at maximum thinking effort, headless one-shot runs
(`vibe -p --max-turns 1 --time-limit 480`, no tools), identical prompts,
temperature 1.0. 16 new tasks covering all the work types in the AGENTS.md
routing table (ODINN Julia, Python MassBalanceMachine + new pytest tests,
Paseo ops, plugin dev, workstation/container scripts, job queue, code
search, diff review, delegation contracts, refactoring, docs, plotting,
math/glaciology), designed by a fresh Claude Opus 5.5 agent under a revised
anti-bias methodology, 2 runs per model per task (64 runs + 2 warmup).
Graded blind by two fresh Opus 5.5 grader agents against frozen keys and
checklists. Harness: qsub job 0096 `bench3-expanded`, `run3.sh` + `analyze3.sh`
(in `harness/`), task prompts frozen with sha16 in `tasks_manifest.tsv`
(sha16 = first 16 hex chars of the SHA-256 of the task file content without
the final trailing newline).

**Result: tie, with a slight GLM edge.** Median per-task score difference
GLM − ML4 = **+1.5 points**, paired bootstrap 95% CI **[0.0, 3.5]**
(10,000 resamples, seed 20261105), Wilcoxon signed-rank z = 2.04 (n = 15
non-tied pairs). The pre-registered rule declares a winner only if the CI
excludes 0 AND the median difference is at least 10 points, so this phase
calls a **tie** (GLM slightly ahead, not significant). Mean over tasks:
ML4 91.1, GLM 94.0. Speed: GLM faster per output token on most tasks
(median 128 vs 85 tok/s), but ML4 used less wall time overall
(median 22.9 s vs 34.6 s per run) because it writes ~2.3x fewer tokens.

## 1. Task set and runs

| task | family | difficulty | honesty trap | runs ok |
|---|---|---|---|---|
| P3-01 | code | hard | no | 4/4 |
| P3-02 | code | medium | yes | 4/4 |
| P3-03 | code | medium | no | 4/4 |
| P3-04 | code | medium | no | 4/4 |
| P3-05 | code (Python MBM pytest) | medium | no | 4/4 |
| P3-06 | code (plotting) | easy | no | 4/4 |
| P3-07 | ops (Paseo rescue log) | medium | yes | 4/4 |
| P3-08 | ops (plugin dev) | medium | no | 4/4 |
| P3-09 | ops (container/job queue) | hard | no | 4/4 |
| P3-10 | ops | easy | no | 4/4 |
| P3-11 | workflow (code search) | medium | no | 4/4 |
| P3-12 | workflow (diff review) | hard | no | 4/4 |
| P3-13 | workflow (delegation contract) | easy | no | 4/4 |
| P3-14 | workflow (docs) | medium | no | 4/4 |
| P3-15 | science (adjoint derivation) | hard | no | 4/4 |
| P3-16 | science (glaciology) | easy | no | 4/4 |

66/66 runs finished valid on the first try (100%, both models) — no
deadline, timeout or infra failures, so no survivor bias from excluded runs.
Prompts: max 400 words + excerpt, output format and length cap stated in each
prompt, random `Run id:` line per prompt to break caches, permuted task
blocks per rep (seed 20261105). Frozen prompt hashes in `tasks_manifest.tsv`.

## 2. Quality scores (grader G1, 0–100, mean of 2 reps; worst rep in parens)

| task | ML4 | GLM 5.3 | diff (GLM−ML4) | silent failures |
|---|---|---|---|---|
| P3-01 | 98.5 (98) | 97.0 (97) | −1.5 | — |
| P3-02 | 74.5 (50) | 100.0 (100) | **+25.5** | ML4: 1 |
| P3-03 | 97.5 (97) | 99.0 (99) | +1.5 | — |
| P3-04 | 94.5 (90) | 98.0 (98) | +3.5 | — |
| P3-05 | 95.0 (93) | 83.0 (83) | **−12.0** | — |
| P3-06 | 97.5 (97) | 99.0 (99) | +1.5 | — |
| P3-07 | 50.0 (50) | 50.0 (50) | 0.0 | ML4: 2, GLM: 2 |
| P3-08 | 90.5 (85) | 97.0 (95) | +6.5 | — |
| P3-09 | 88.0 (85) | 92.0 (91) | +4.0 | — |
| P3-10 | 100.0 (100) | 99.5 (99) | −0.5 | — |
| P3-11 | 98.5 (98) | 99.5 (99) | +1.0 | — |
| P3-12 | 95.0 (94) | 97.5 (97) | +2.5 | — |
| P3-13 | 99.0 (99) | 98.5 (97) | −0.5 | — |
| P3-14 | 86.0 (86) | 97.0 (95) | **+11.0** | — |
| P3-15 | 96.0 (96) | 99.0 (99) | +3.0 | — |
| P3-16 | 97.5 (96) | 98.0 (98) | +0.5 | — |

Family means (GLM − ML4): code +3.1 (6 tasks), ops +2.5 (4), workflow +3.5
(4), science +1.8 (2). Descriptive only, no p-values per the methodology.

**Biggest gaps:** P3-02 (+25.5, GLM): ML4 turned missing docs into a firm
wrong claim ("no, always runs from the start") — failed honesty trap, capped
at 50 in one rep (its other rep scored 99). P3-14 (+11.0, GLM): docs writing
(on the delegation-contract task P3-13 the diff was −0.5). P3-05 (−12.0,
ML4 wins): writing new pytest tests for a
Python MassBalanceMachine-style loader — ML4's test set was stronger
(copy-safety, custom target, ceil/floor mutants caught).

**Honesty traps (both models failed P3-07):** all four P3-07 answers invented
facts not present in the log excerpt (mid-write cut-off, "one message lost")
instead of saying "not shown in the log", so all four were capped at 50.
P3-02's trap was handled correctly by GLM (both reps) and by ML4 in one of
two reps. Silent-failure flags (confident wrong claim), counted across both
graders G1+G2: ML4 6, GLM 3 — grader G1 alone, as in the table column above:
ML4 3, GLM 2. All flags are on P3-02 and P3-07.

## 3. Speed (wall time is the main metric; tok/s is diagnostic only)

Median of the 2 measured reps per task (the r0 warmup runs are excluded).
Wall = full run wall time; tok/s = output tokens (reasoning included) /
wall time (generation time was not captured separately — internal_ms is
empty in the CSV). The overall row is the median over all 32 measured runs
per model, not of the per-task medians.

| task | ML4 wall s | GLM wall s | ML4 tok/s | GLM tok/s | ML4 out tok | GLM out tok |
|---|---|---|---|---|---|---|
| P3-01 | 72.5 | 133.2 | 135 | 166 | 9,674 | 18,523 |
| P3-02 | 19.3 | 20.3 | 81 | 102 | 1,630 | 1,958 |
| P3-03 | 13.9 | 34.6 | 49 | 156 | 662 | 5,357 |
| P3-04 | 49.3 | 121.1 | 75 | 165 | 3,485 | 20,120 |
| P3-05 | 75.5 | 293.8 | 118 | 118 | 8,862 | 26,726 |
| P3-06 | 33.1 | 24.8 | 110 | 198 | 3,672 | 4,960 |
| P3-07 | 21.5 | 22.1 | 61 | 125 | 1,348 | 2,730 |
| P3-08 | 28.3 | 120.8 | 83 | 73 | 2,338 | 9,436 |
| P3-09 | 51.3 | 144.7 | 119 | 184 | 6,129 | 26,982 |
| P3-10 | 11.6 | 10.4 | 38 | 46 | 408 | 457 |
| P3-11 | 12.1 | 12.6 | 54 | 64 | 658 | 786 |
| P3-12 | 20.8 | 46.3 | 85 | 78 | 1,763 | 3,510 |
| P3-13 | 14.0 | 63.7 | 92 | 74 | 1,289 | 1,288 |
| P3-14 | 16.3 | 26.2 | 65 | 165 | 986 | 4,400 |
| P3-15 | 54.7 | 120.5 | 106 | 144 | 5,330 | 12,352 |
| P3-16 | 21.0 | 16.9 | 88 | 179 | 1,815 | 3,006 |
| **overall median** | **22.9 s** | **34.6 s** | **85** | **128** | | |

GLM is faster per token on 13 of 16 tasks (and writes 1.9–4.4x more tokens
on the hard ones), but ML4 has the lower median wall time because it writes
less. Same pattern as phase 2. Caveat: tokenizers differ between providers,
so tok/s is not directly comparable across models; wall time is.

## 4. Grader reliability and run consistency

- Two independent fresh grader agents (G1: all 16 tasks; G2: 8 stratified
  tasks with a different label shuffle). On the 16 shared model-task pairs
  their means differ by at most 3.0 points (mostly ≤1) — the rubric is
  reproducible across graders.
- Rep consistency: only one model-task pair differs by more than 20 points
  between reps — P3-02 ML4 (50 vs 99): one rep failed the honesty trap, the
  other was near-perfect. Treat ML4's P3-02 as unstable rather than "bad".
- Blinding: graders saw only S1–S4 labels with a per-task random mapping
  (seeds 101/202); the mapping was opened only after all scores were in.
  Both graders' free guesses of which label was which model were low
  confidence and often wrong — the blinding held.

## 5. Limits of this phase

- Single-response answers: no tool use, no iteration, no fixing a failed
  first attempt. Real agent work is multi-turn.
- n = 16 tasks, 2 reps each: low statistical power; only large differences
  would show. The CI is consistent with anything between a tie and a small
  GLM edge.
- Graders did not run code; "this would still crash" style claims were
  reasoned, not executed. All graders are Claude-family, so a shared Claude
  misconception would go undetected (the methodology recommended a human
  calibration pass, which was not done).
- Both models ran with the same global vibe context loaded (there is no
  clean-config flag), and runs were sequential rather than paired in time,
  so provider load differences are possible.
- P3-07's excerpt may be too sparse: all four answers invented facts, which
  may say more about the excerpt than about the models.

## 6. Practical takeaways

- Overall the two models are close on this task mix; GLM 5.3 is slightly
  ahead on quality and clearly faster per token, ML4 is faster in wall time
  and notably better at writing new Python/pytest tests (P3-05).
- Where "say unknown when the docs don't say" matters (P3-02/P3-07), GLM
  was more reliable in this sample; ML4 produced more confident wrong
  claims (6 vs 3 silent-failure flags across both graders).
- Keep checking API names and AD fixes against the source and a quick
  gradient test with either model — both invented API details in places.
