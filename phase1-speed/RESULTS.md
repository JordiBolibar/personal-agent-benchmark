# Benchmark results: Mistral Large 4 vs GLM 5.3 (max effort)

Date: 2026-11-03/04. Method: one-shot headless `vibe -p` runs, identical prompt
(/tmp/vibe-bench/prompt.md, self-contained Julia task, no tools, --max-turns 1),
1 warmup + 5 measured runs per model, interleaved A/B, sequential. Speed metric:
output tokens / generation time, using API usage counts (output_tokens INCLUDES
reasoning tokens) over the export.json started_at->ended_at window; external
wall clock matches within ~0.2%.

Effort levels (verified in each run's export.json): GLM 5.3 thinking="max"
(levels low/high/max). Mistral Large 4 thinking="high" — its only non-off level,
i.e. its maximum. Both temperature=1.0 during the benchmark (config restored
afterwards).

## Valid runs (outcome=finished, steps=1, exit 0)

| run              | wall (s) | output tok | tok/s | cached in |
|------------------|---------:|-----------:|------:|----------:|
| glm-5-3 r1       | 111      | 11546      | 103.8 | 15552     |
| glm-5-3 r2       | 96       | 14031      | 145.5 | 0         |
| glm-5-3 r3       | 56       | 8216       | 147.1 | 0         |
| glm-5-3 r4       | 83       | 14477      | 174.1 | 0         |
| glm-5-3 r5       | 263      | 26606      | 101.1 | 15552     |
| large-4 r1       | 29       | 1768       | 61.8  | 15360     |
| large-4 r3       | 21       | 1153       | 54.3  | 2816      |
| large-4 r4       | 285      | 2084       | 7.3   | 512       |
| large-4 r5       | 28       | 2386       | 86.1  | 512       |

Excluded: mistral-large-4 r2 (deadline after 2.5 h, 0 tokens — server-side hang),
glm-5-3 ttft first attempt (timeout 33 min, 0 tokens; retried as ttft2, ok).
Warmups (discarded): large-4 33 s / 3980 tok, glm 76 s / 13311 tok.

## Summary

| metric                     | GLM 5.3 (max)  | Mistral Large 4 (high) |
|----------------------------|----------------|------------------------|
| valid runs                 | 5              | 4                      |
| median output speed        | 145.5 tok/s    | 58.1 tok/s             |
| min–max output speed       | 101–174 tok/s  | 7.3–86.1 tok/s         |
| median excluding outliers* | 145.5 tok/s    | 61.8 tok/s             |
| median wall time per task  | 96 s           | 28 s                   |
| total output tokens (5/4)  | 74876          | 7391                   |

*large-4 r4 (7.3 tok/s) ran during a server congestion window (21:34–21:39 UTC,
the Paseo store-repair incident); median of the other 3 runs = 61.8 tok/s.

## Reading

- Per generated token, GLM 5.3 is about 2.3–2.5x faster than Mistral Large 4
  (145 vs ~58–62 tok/s median) at max thinking.
- Per task, Large 4 finished sooner on wall clock (28 s vs 96 s median) because
  it produced ~10x fewer output tokens (shorter reasoning/answer); GLM wrote
  much longer responses on the same prompt.
- TTFT could not be measured precisely: `--output streaming` emits turn-level
  events only (user-turn, reasoning, assistant). First server-side event
  (reasoning complete) arrived at +30.5 s of a 31 s turn (large-4) and +41.6 s
  of a 42 s turn (glm ttft2).
- Reliability note: Large 4 had one 2.5 h hang (r2); GLM had one 33 min hang on
  the first streaming attempt. Both excluded from the stats.
- Caveat: repeat runs sometimes hit prompt cache (cached_input_tokens > 0),
  which lowers input cost/time but does not affect the output tok/s metric.

Raw data: /tmp/vibe-bench/out/*/export.json, out/timing.log, out/all_runs.jsonl,
out/run.log. Review of the method: /tmp/vibe-bench/review.md.
