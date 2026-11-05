#!/bin/bash
# One-off: retry GLM 5.3 streaming TTFT run (previous attempt hit the timeout).
set -u
BENCH=/tmp/vibe-bench
OUT=$BENCH/out
export VIBE_ENABLE_UPDATE_CHECKS=false
export VIBE_ENABLE_TELEMETRY=false
dir=$OUT/glm-5-3_ttft2
rm -rf "$dir"; mkdir -p "$dir"
t0=$(date +%s%N)
VIBE_ACTIVE_MODEL=glm-5-3 timeout 240 vibe -p --workdir "$BENCH" \
  --prompt-file "$BENCH/prompt.md" --output streaming \
  --max-turns 1 --time-limit 230 --output-dir "$dir" \
  2>"$dir/stderr.log" | while IFS= read -r line; do
    printf '%s %s\n' "$(date +%s%N)" "$line"
  done > "$dir/stream.log"
rc=${PIPESTATUS[0]}
t1=$(date +%s%N)
echo "glm-5-3 ttft2 stream $t0 $t1 $rc" >> "$OUT/timing.log"
echo "done glm ttft2 rc=$rc" >> "$OUT/run.log"
