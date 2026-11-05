# Phase 3 methodology review

## 1. Biases and weaknesses

**Task sample**
1. **One task per work type:** a single task cannot support a claim like "model X is better at Python". Task variance probably matters more than run variance.
2. **Designer's taste:** I wrote most of the tasks, so they lean towards the depth I value, and they may favour one model's style.
3. **Ceiling effects:** T8 was a 5/5 tie, so easy tasks do not separate the models. There was no planned difficulty spread.
4. **Missing context:** neither model knows Paseo, your plugins or your scripts. Without an excerpt in the prompt, these tasks only measure guessing.
5. **Prompt length:** long excerpts can change latency and caching, so prompt length must be recorded.
6. **No honesty traps:** no task tested if a model says "unknown" when the answer is not available.

**Run conditions**

7. **Different time windows:** A/B order still puts each model's runs at different times. Provider load also follows different time zones.
8. **Possible context leak:** `vibe` may load `~/.vibe/AGENTS.md`, skills or project files. This could add input or context, and it should be checked.
9. **Unequal settings:** ML4 `high` and GLM `max` are not the same thinking budget, and temperature 1.0 may not mean the same thing on both. Output caps may also differ and cause truncation.
10. **Cache and model changes:** repeated prompts may hit a cache. Model versions can also change between phases, so the model ID and date must be logged.

**Metrics**

11. **Tok/s is weak:** tokenizers differ between providers, and reasoning tokens are counted too. A model can have high tok/s and still answer later.
12. **Unbalanced medians:** ML4 had n=9 and GLM had n=8, so their medians mix different task sets.
13. **Survivor bias:** failed runs were excluded. If the failed runs are the long ones, speed looks better than it is.
14. **Outliers need a rule:** a run must be excluded only by an objective cause, like host sleep, and never because its value looks large.

**Grading**

15. **I am no longer a neutral grader:** I wrote the phase 2 verdict that favoured GLM, so I should not grade phase 3.
16. **Length bias:** long answers show more depth and get more credit, while their extra errors are harder to spot. GLM writes about 3× the tokens per run.
17. **Style is not fully blind:** removing model names does not hide writing style.
18. **Claims were not executed:** "this code should still crash" (T4) was reasoned, not run. Phase 2 scores stay provisional.
19. **Silent failures are hidden:** a confident wrong fix costs you more than a visible gap, but one average score hides this.
20. **Shared grader errors:** every grader so far is Claude, so a Claude misconception would go undetected without oracles or your own checks.
21. **Low statistical power:** even 16 tasks can show only large differences.

**Limit to state in the report:** these results describe single-response answers. They do not measure tool use, iteration or fixing a failed attempt.

## 2. Revised methodology

### 2.1 Tasks: 16 tasks in 4 families

| Family | Tasks |
|---|---|
| **Code (6)** | ODINN Julia/AD debug; ODINN design using an API excerpt; Julia refactor that must keep behaviour; writing tests (Julia); MassBalanceMachine Python; plotting |
| **Ops (4)** | Paseo diagnosis from a log excerpt; plugin development; workstation/container script; job queue failure and resume |
| **Workflow (4)** | Code search (choose queries, judge ranked results); diff review (the text version of visual review); writing a delegation contract; docs writing |
| **Science (2)** | Math/AD derivation; glaciology theory |

- **Difficulty:** use 4 easy, 8 medium and 4 hard tasks, with at least one easy or hard task in each of Code, Ops and Workflow.
- **Prompt limits:** at most 400 words of prompt plus 800 words of excerpt. Every prompt states the output format and a length cap.
- **Honesty traps:** at least 2 tasks ask about something absent from the excerpt. The correct answer is "not in the excerpt". Note these in the answer key, not in the prompt.
- **New tasks only:** do not reuse phase 2 tasks. The Science family stays small because phase 2 already covered it.

### 2.2 Runs

Time estimates below use phase 2 medians. Practical tasks are unmeasured, so the time guard is what enforces the limit.

| Item | Setting |
|---|---|
| Runs | 2 per task per model, 64 in total |
| Execution | Start one ML4 and one GLM run at the same moment, as a pair |
| Warmup | 1 pair with a fixed short prompt, not scored. Repeat after any pause over 10 min |
| Order | Rep 1 of all tasks first, then rep 2. Each rep uses permuted blocks of 4 tasks, with a saved seed and a different order per rep |
| Windows | If possible, run rep 1 and rep 2 at least 6 h apart |
| Estimated time | 46 min per rep (60/180/270 s for easy/medium/hard pairs), so about 92 min plus warmup |
| Time guard | No new run after 110 min. With the deadline below, the hard end is 118 min |

**Check for pairing:** in the dry run, compare one solo run with one paired run per model. If paired runs cause timeouts or differ by more than 20% in wall time, run sequentially. Then do rep 1 on all 16 tasks and rep 2 on 8 tasks chosen in advance, stratified by family.

**Setup rules**
- Start each prompt with a unique line: `Run id: <random>. Ignore this line.` This breaks exact and prefix caches for the prompt.
- Run from an empty working directory with a clean `vibe` config. In the dry run, check that both models get the same context and that no skills or `AGENTS.md` are loaded.
- Log model ID, thinking level, temperature, output cap, prompt hash, UTC start and system load.
- Submit through `qsub` with `nice`. Keep everything in a persistent folder and keep `STATE_LIVE.md` updated.
- Make the harness resumable: it skips any run that already has a valid `status.json`.

**Run loop**
```text
heartbeat writer: append a timestamp every 5 s
for each rep, block and task:
    stop if elapsed > 110 min
    start ML4 and GLM with `timeout 480`
    save stdout, stderr, exit code, export.json, start and end times
    classify the run and write results.csv
at the end of each rep: retry the eligible runs
```

### 2.3 Failure handling

| Class | Detection | Retry | Treatment |
|---|---|---|---|
| `ok` | Exit 0, non-empty answer, not truncated | None | Graded |
| `host_suspended` | Heartbeat gap over 20 s during the run | Up to 2 | Run invalid, not charged to the model |
| `server_error` | Provider or app-server error, or missing export | Up to 2 | Not charged if a retry succeeds |
| `deadline` | Reached 480 s | None | Scores 0 in the main analysis |
| `empty` | Exit 0 with no answer | 1 | Counts against the first-try rate |
| `truncated` | Output cap reached | None | Graded as it is, and flagged |

- Grade the first valid answer. Never choose the better of two attempts.
- If all retries of a charged failure class fail, score 0. If only infrastructure failures remain, drop that task pair from the paired analysis and report it.
- Report quality in two ways: all runs (failures = 0) and valid runs only.

### 2.4 Metrics

- **Main speed metric:** wall time per task, from a monotonic clock. Report it per task and as median, IQR and p90 over paired tasks.
- **Secondary:** visible answer characters per second, measured the same way for both models.
- **Diagnostic only:** reported tok/s and reasoning tokens (taken from the export, or total minus an estimate of visible tokens, and marked as an estimate).
- **Reliability:** first-try valid rate per model, with counts of each failure class.
- **Cache:** log cached tokens if the export has them, and compare rep 1 with rep 2.
- **Outliers:** do not trim values. Exclude only by the failure classes above.
- **No composite score:** show quality and time side by side.

### 2.5 Validation before the benchmark

1. **Author:** write the prompt, excerpt, answer key, weighted checklist and oracle, if the task can have one.
2. **Definitions check:** every symbol and constant must be defined. This catches a T2-type flaw. Pin every API excerpt to a commit SHA and list names in a fact sheet, which addresses T7-type flaws.
3. **Self-solve:** solve each task from the prompt alone. Compute numeric keys with a script. Oracles must pass on the correct solution and fail on a planted wrong one.
4. **Blind review:** a fresh agent sees only the prompts and lists missing definitions, other valid readings and hidden knowledge. Fix every blocking item.
5. **Pilot:** run all tasks on a cheap third model, not ML4 or GLM. Check format, timing, oracles and signs of floor or ceiling effects.
6. **Privacy check:** these prompts go to external providers, and phase 3 uses private infrastructure material. Remove tokens, emails, hostnames, private paths and unpublished results.
7. **User approval and freeze:** you approve the final task set before anything is sent. Save SHA-256 hashes of prompts, keys and checklists. After this, log flaws but do not edit.

### 2.6 Grading

**Oracles first:** run them before human or agent grading, and give graders the output.

| Task type | Oracle |
|---|---|
| Python, plotting | Hidden pytest, or checks on the plot output and data |
| Bash | `shellcheck` plus fixture tests |
| Julia | Small tests on Julia 1.11, only after you approve these runs |
| Writing tests | Tests must pass on correct code and fail on planted bugs |
| Numeric answers | Comparison with the scripted key |

Model code is untrusted, so run it sandboxed, with no network and in a separate directory.

**Rubric (0-100)**

| Part | Points | How |
|---|---|---|
| Checklist | 70 | 6-12 frozen items, weighted critical 3, major 2, minor 1 |
| Honesty | 10 | Invented APIs, false claims of verification, unmarked guesses |
| Compliance | 10 | Format, covers all parts, within length cap plus 20% |
| Usability | 10 | 0, 5 or 10, with anchor examples written for each task |

- A failed critical item caps the task score at 50.
- Items not on the checklist earn no extra points. Extra length therefore earns nothing.
- Graders may record errors outside the checklist, and these reduce the honesty or usability score with a short reason.
- **Silent failure flag:** set it when an answer presents a critical error as finished or verified. Count these flags separately.

**Graders and bias control**
- **Designer:** I write tasks and keys only. I do not grade.
- **G1:** a fresh agent per task, with no phase 1-2 context. It grades all answers for that task, up to 4, in random order under random labels.
- **G2:** a fresh agent with a different answer order. It grades 8 tasks picked in advance by family, plus any task with one-sided critical failures or a model difference of 10 points or less.
- **Sources:** graders get read-only sources at the pinned SHAs, the fact sheet and the oracle output. They do not see metrics or model names.
- **Blinding check:** each grader guesses the model after scoring. Report guess accuracy.
- **Disagreements:** if G1 and G2 differ by more than 15 points, or on a critical item, settle it by oracle or source. If that is not enough, you decide while still blind.
- **Human calibration (recommended):** you grade 4 tasks blind, including Science and the ODINN design task. This takes about 16 answers and is the only check against shared Claude errors.
- **Flawed tasks:** decide while still blind. Report results with and without the flawed task.
- **Between runs:** grade each run separately. For each model and task, report the mean and the worst run, since you only get one draw in real use. Flag a task if its runs differ by more than 20 points or on a critical item.

### 2.7 Analysis rule (fix before running)

- The unit of analysis is the task, not the run. Average the reps, then compute GLM minus ML4 per task.
- Report the median difference, a paired bootstrap 95% CI over tasks (10,000 resamples, saved seed) and a Wilcoxon signed-rank test as a secondary check.
- **Overall winner:** only if the CI excludes 0 and the median difference is at least 10 points. Otherwise call it a tie.
- **Family results:** descriptive only, with no p-values. Science is too small to support a conclusion alone.

### 2.8 Final report

1. Dates, model IDs, settings, harness version and the frozen hashes.
2. Any change from this plan, and why.
3. Run counts: planned, valid, retried and failed, by class.
4. A per-task table: mean and worst score for each model, wall time and flags.
5. Family summaries and the overall result with its CI.
6. Silent failure counts, invented API lists and honesty trap results.
7. Oracle pass rates, separate from the graded scores.
8. Speed tables, with tok/s clearly marked as diagnostic.
9. Run consistency and the rep 1 vs rep 2 comparison.
10. Grader agreement, blinding check results and your calibration against the graders.
11. Flawed tasks, with results both with and without them.
12. Limits, including single-response tasks, task sampling and low statistical power.
13. A practical recommendation by work type, with the evidence level stated. Links to all raw answers and grades.

## 3. Practical notes

- **Checks for the dry run:** I have not confirmed that `vibe` supports a clean config, that the export separates reasoning or cached tokens, or that pairing is safe. If a field is missing, report that metric as unavailable.
- **Time outside the limit:** task authoring, the pilot, oracles and grading are not part of the 2 hours of run time. They are still a real cost, mostly in Claude tokens.
- **Approvals needed from you:** the final task set before it goes to the providers, and the Julia oracle runs.
- **If you need to cut scope:** drop G2's extra tasks first. Keep the oracles, the frozen checklists and fresh graders, because they fix the largest weaknesses from phase 2.