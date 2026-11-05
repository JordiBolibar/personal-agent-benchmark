# Independent review: model speed benchmark plan (vibe 3.0.2)

Reviewed 2026-11-03. Read-only: no repo files edited, no Julia run, no model run.
One probe was done with a MISSING prompt file, which fails before any model call
(export showed `outcome: usage_error`, exit 1) — used only to confirm flag parsing
and the export schema. Probe artifacts were removed afterwards.

Path shorthands:
- `SP` = /home/jordi/.local/share/uv/tools/mistral-vibe/lib/python3.12/site-packages/vibe
- `H`  = .../site-packages/mistralai_vibe_local_harness
- `BIN` = /home/jordi/.local/bin/vibe (execs the Rust `SP/_bin/vibe-rs`, which spawns
  the Python app-server; see `SP/cli/launcher.py:31-56`)

## a) Are the CLI flags valid for vibe 3.0.2?

Severity: low (OK).

Evidence: `vibe --version` prints `vibe 3.0.2`. `vibe --help` lists `-p, --prompt`,
`--prompt-file <PATH>` ("Run in programmatic mode with the prompt read from PATH,
instead of -p TEXT or stdin"), `--output text|json|streaming`, `--max-turns`,
`--max-price`, `--max-tokens`, `--time-limit`, `--output-dir <DIR>` ("On every exit,
write export.json ... and a copy of the session journal (session/) to DIR").
Probe: `VIBE_ACTIVE_MODEL=glm-5-3 vibe -p --prompt-file <missing> --output json
--max-turns 1 --max-price 5 --output-dir ...` parsed fine and errored on the missing
file before any model call, so `-p` (no value) + `--prompt-file` is a valid combo.
Note: the flag parsing lives in the Rust binary (not shipped as source); the Python
side receives a run request with these fields (`SP/app_server/protocol.py:391`).

## b) Does VIBE_ACTIVE_MODEL=<alias> resolve the alias and apply per-model thinking?

Severity: low (verified, with one nuance).

Evidence:
- `SP/core/config/layers/environment.py:17,26` — env layer reads `VIBE_*` via
  pydantic-settings (`env_prefix="VIBE_"`, `env_ignore_empty=True`), so
  `VIBE_ACTIVE_MODEL=glm-5-3` sets `active_model`.
- `SP/core/config/default_orchestrator.py:68-79` — layer order is
  Default < ModelCatalog < Growthbook < user < project < Environment < overrides,
  so the env var beats `active_model = "mistral-large-4"` in config.toml.
- `SP/core/config/vibe_schema.py:988-1004` — `get_active_model()` looks the value up
  in the models map, which is keyed by alias (`SP/core/config/models.py:579-592`),
  so `glm-5-3` and `mistral-large-4` resolve to their `[[models]]` entries.
- config.toml: `glm-5-3` has `thinking = "max"` and `thinking_levels = [low, high, max]`
  so the level is kept (`_reset_thinking_outside_levels`, models.py:563-575);
  `mistral-large-4` has `thinking = "high"`, `thinking_levels = [off, high]`.
- The run passes `thinking=active_model.thinking` into the model route
  (`SP/app_server/_runtime.py:1580`; `H/vibe/_runtime_config.py:443-455`).
- On the wire: GLM goes through provider `mistral-openai` (backend generic,
  api_style "reasoning") and the generic adapter sends the level verbatim:
  `payload["reasoning_effort"] = thinking` when != "off"
  (`H/vibe/adapters/generic/_base.py:31-33`) — so `reasoning_effort: "max"`.
  Mistral Large 4 goes through the native mistral adapter, where
  `_THINKING_TO_REASONING_EFFORT = {low: none, medium: high, high: high, max: high}`
  (`H/vibe/adapters/mistral.py:80-85`) — so `reasoning_effort: "high"`.
  Nuance: the native Mistral API only accepts none/high, so "max" does not exist
  there; GLM's "max" is passed through the OpenAI-compatible endpoint and whether
  the server honors "max" is outside the CLI's control. The plan's mapping
  (GLM max, Large 4 high) is correct.

## c) Does --output-dir export.json include usage, cost, stop reason, config?

Severity: low (verified), one medium caveat on token fields.

Evidence: schema in `SP/app_server/run_export.py:100-235` and a real probe export.
Fields: `outcome`, `stop_reason` (TurnStop: interrupted/limit/length,
`SP/app_server/models.py:384-393`), `error`, `session_id`, `usage`, `cost_usd`,
`steps`, `config` (redacted effective config), `warnings`, `schema_version`,
`vibe_version`, `journal_dir` + `session/` journal copy, `started_at`, `ended_at`,
`limits`, `subagents`, `exit_code`. Written on EVERY exit, including errors
(probe with a missing prompt file still wrote export.json with exit_code 1).
- `usage` = `{input_tokens, output_tokens, cached_input_tokens, total_tokens}`
  only (run_export.py:118-124). There is NO reasoning-token breakdown:
  `output_tokens` is whatever the provider reports as `completion_tokens`
  (`H/vibe/adapters/mistral.py:663-686`, `generic` adapters read
  `usage.completion_tokens` too; streaming requests set
  `stream_options.include_usage = true`, `H/vibe/adapters/generic/_openai_chat.py:113`
  and `reasoning_adapter.py:118`), and for reasoning models that count includes
  reasoning tokens. So the plan's "completion tokens" = all generated tokens
  including thinking, for both models; the export cannot split them.
- `started_at`/`ended_at` give the run's own time window — usable instead of, or in
  addition to, the external wall clock.

## d) Is completion_tokens / wall_time a sound speed metric?

Severity: medium. Usable as a rough end-to-end metric, but it mixes several things.

Evidence and confounds:
- Wall time (date +%s%N around the process) includes: Rust CLI startup, spawning the
  app-server child ("Started an app-server for run", strings in vibe-rs), config +
  model-catalog load, MCP server spawn (the `xerj` stdio command in config.toml points
  to /Users/Bolib001/... which does not exist on this Linux box, so it fails — a
  startup warning, export `warnings`), hooks load, system-prompt build
  (~/.vibe/AGENTS.md is always loaded), THEN the model call (prefill + decode +
  network RTT), then export + journal copy, then process teardown.
- Prefill is inside wall time and depends on prompt caching: the Mistral API reports
  cache hits as `prompt_tokens_details.cached_tokens`, surfaced as
  `usage.cached_input_tokens`. Repeating the identical prompt will likely hit the
  server-side cache on runs after the warmup, making prefill cheaper — a real effect
  on wall time, visible per run via `cached_input_tokens`.
- Retries: `api_retry_max_elapsed_time = 300` default (config.toml) and
  `call_with_retries` (`H/vibe/adapters/_retry.py`); a failed stream is retried,
  inflating wall time. Filter these out by requiring `outcome == "finished"`.
- Tool calls: see (f); a run that touched tools is not a clean generation.
- No TTFT: `--output json` waits for the full response. `--output streaming` exists
  and streams deltas, so the runner could timestamp stream lines and get
  time-to-first-token and inter-token gaps (true decode speed).

Suggested improvements: report BOTH external wall time and `ended_at - started_at`
from export.json; set `VIBE_ENABLE_UPDATE_CHECKS=false` and `VIBE_ENABLE_TELEMETRY=false`
for the bench runs to cut startup noise; record `cached_input_tokens` per run; compute
tokens/sec as `output_tokens / (ended_at - started_at)` as the primary metric and wall
time as sanity check; optionally add a `--output streaming` variant with line
timestamps for TTFT; require `outcome == "finished"` and `steps == 1` for a run to
count.

## e) Is 1 warmup + 5 interleaved sequential runs per model reasonable?

Severity: low. Reasonable as a minimum; small improvements possible.

Evidence: design itself (sequential, interleaved A/B) is correct — parallel runs would
confound each other on a shared box, and interleaving counters time drift. 1 warmup
also warms the server-side prompt cache, which is what you want for steady-state
decode measurement (but then prefill is cache-served; report `cached_input_tokens`).
If time allows, 10 measured runs per model gives a tighter median; median/min/max is
the right summary. Run all runs from the same cwd (e.g. /tmp/vibe-bench) so project
context is identical (not a git repo, so no git info; ~/.vibe/AGENTS.md is identical
for both models, so it does not bias the comparison).

## f) Could the two models get different treatment that confounds speed?

Severity: HIGH for temperature; medium for max-turns semantics; low for the rest.

1. HIGH — temperature differs. The plan says "both have temperature 1.0", but
   config.toml sets `temperature = 1.0` only for `mistral-large-4`; `zai-glm-5-3` has
   NO temperature, so it gets the schema default `temperature: float = 0.2`
   (`SP/core/config/models.py:508`). The request sends `temperature: route.temperature`
   (`H/vibe/adapters/mistral.py:134`, `H/vibe/adapters/generic/_execute.py:191`).
   Fix: add `temperature = 1.0` to the glm-5-3 entry (or accept and document 0.2 vs 1.0).
   Temperature mostly changes output, not speed, but it changes token counts and the
   comparison is then not "same settings".
2. MEDIUM — `--max-turns 1` does NOT guarantee a single clean completion. It maps to
   `max_iterations` (`SP/app_server/_runtime.py:1412`), i.e. at most ONE model call
   (`ModelRequest.iteration/max_iterations`, `H/runtime.py:101-107`). If the model
   emits a tool call, headless mode has no approval responder and the call is denied
   ("Deny (or headless, with no responder) fails the call back to the model",
   `H/vibe/_local_actions.py:1474-1483`); the loop then cannot make a second model
   call, so the run ends with `outcome: "turn_limit"`, `stop_reason: "limit"`, exit 3.
   Note some tools have `permission = "always"` in config.toml (read_file, write_file,
   edit, todo, ask_user_question...), so under default agent `accept-edits`
   (`vibe_schema.py:661-665`, config.toml does not set default_agent) a read_file call
   WOULD execute and its time would land inside the run. The "do not use any tools"
   prompt mitigates this, but the plan must assert `outcome == "finished"` and
   `steps == 1` per run and exclude/flag the rest.
3. LOW — provider/region: both providers use `api_base = https://api.mistral.ai/v1`;
   `region` is only consumed by the Vertex backend (`SP/core/config/models.py:156`,
   `H/vibe/adapters/generic/_vertex.py`), and the mistral adapter builds the server URL
   from api_base only (`H/vibe/adapters/mistral.py:427-430`). So `region = "eu-west-1"`
   on the mistral provider does not change the endpoint — no region confound. The wire
   protocol differs (native SDK vs OpenAI-compatible POST), which is inherent to how
   each model is served.
4. LOW — system prompt and tools are the same for both (`system_prompt_id = "cli"`,
   `include_*` all true, `enabled_tools = []` = all tools; only two xerj tools are
   disabled). `include_model_info = true` puts the model name in the prompt — trivial.
   The broken xerj MCP command path (macOS path on Linux) adds the same startup warning
   to both models. Session-title generation is interactive-only, so no hidden utility
   model call in -p mode; `steps` in the export counts only the agent's own calls.

## g) Does --max-price interrupt mid-run? Is it an acceptable guard?

Severity: HIGH — with the current config.toml the guard can never trigger.

Evidence:
- Cost is computed ONLY from the configured per-model prices:
  `session_token_cost(...)` (`SP/utils/pricing.py`) is fed from
  `active_model.input_price/output_price/cached_input_price`
  (`SP/app_server/_runtime.py:2200`, `SP/app_server/models.py:474-483`).
  `ModelConfig` defaults are `input_price = 0.0`, `output_price = 0.0`
  (`SP/core/config/models.py:511-512`), and NEITHER `mistral-large-4` NOR
  `zai-glm-5-3` sets prices in config.toml (the model-catalog layer does not fetch
  prices either, `SP/core/config/layers/model_catalog.py:28-38`). So `cost_usd` is
  always 0.0 for both models and `--max-price 5` never trips.
- When it does trip (prices configured), the run ends with `outcome: "price_limit"`,
  exit code 3, and the export is still written; the docstring says the partial work is
  kept ("What it left is still its own work, to be scored", run_export.py:42-45).
  The check itself lives in the Rust core (outcome strings in vibe-rs), not in the
  shipped Python, so whether it can interrupt mid-stream is not verifiable here;
  `--time-limit` is the flag that explicitly interrupts mid-run ("Interrupt the run
  once SECONDS have passed since start, write the export and exit 3", --help).
- Acceptable as a guard only if prices are set; otherwise prefer `--time-limit`.
  Either way, treat any run with `outcome != "finished"` as invalid for the benchmark.

## Verdict

Required changes before running:

1. Fix the temperature mismatch: add `temperature = 1.0` to the `glm-5-3` entry in
   config.toml (currently it silently runs at the default 0.2 while mistral-large-4
   runs at 1.0), or explicitly document the difference in the report.
2. `--max-price 5` is a no-op here because both models have price 0.0 configured, so
   `cost_usd` stays 0. Either add real `input_price`/`output_price` to both
   `[[models]]` entries, or drop `--max-price` and use `--time-limit` as the safety
   guard. In all cases, only count runs with `outcome == "finished"` and `steps == 1`.
3. Use export.json's `started_at`/`ended_at` alongside the external wall time (the
   export window excludes process startup), and set `VIBE_ENABLE_UPDATE_CHECKS=false`
   and `VIBE_ENABLE_TELEMETRY=false` in the runner env to reduce startup noise.
4. Record `usage.cached_input_tokens` per run (identical prompts will likely be
   cache-served after the warmup) and state that `output_tokens` includes reasoning
   tokens — the export has no reasoning/visible split.
5. Optionally add a `--output streaming` pass with line timestamps for
   time-to-first-token / decode-only speed, since wall time includes prefill.

Everything else in the plan (flags, VIBE_ACTIVE_MODEL resolution, thinking=max for
GLM 5.3 vs high for Mistral Large 4, export.json fields, warmup + 5 interleaved
sequential runs) checked out against the installed 3.0.2 source.
