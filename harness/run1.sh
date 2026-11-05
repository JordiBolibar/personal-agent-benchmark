#!/bin/bash
# Benchmark: Mistral Large 4 vs GLM 5.3, both at max thinking, one-shot headless runs.
# Usage: bash /tmp/vibe-bench/run.sh
set -u
BENCH=/tmp/vibe-bench
OUT=$BENCH/out
mkdir -p "$OUT"
export VIBE_ENABLE_UPDATE_CHECKS=false
export VIBE_ENABLE_TELEMETRY=false
TIME_LIMIT=600
RUNS=5
MODELS="mistral-large-4 glm-5-3"

log() { echo "$(date -Iseconds) $*" >> "$OUT/run.log"; }

run_one() {
  local model=$1 tag=$2 mode=$3
  # resume support: skip if this run already has a timing entry
  if grep -q "^$model $tag $mode " "$OUT/timing.log" 2>/dev/null; then
    log "skip $model $tag $mode (already done)"
    return
  fi
  local dir=$OUT/${model}_${tag}
  rm -rf "$dir"; mkdir -p "$dir"
  local t0 t1 rc
  t0=$(date +%s%N)
  if [ "$mode" = "stream" ]; then
    VIBE_ACTIVE_MODEL="$model" timeout 400 vibe -p --workdir "$BENCH" \
      --prompt-file "$BENCH/prompt.md" --output streaming \
      --max-turns 1 --time-limit "$TIME_LIMIT" --output-dir "$dir" \
      2>"$dir/stderr.log" | while IFS= read -r line; do
        printf '%s %s\n' "$(date +%s%N)" "$line"
      done > "$dir/stream.log"
    rc=${PIPESTATUS[0]}
  else
    VIBE_ACTIVE_MODEL="$model" timeout 400 vibe -p --workdir "$BENCH" \
      --prompt-file "$BENCH/prompt.md" --output json \
      --max-turns 1 --time-limit "$TIME_LIMIT" --output-dir "$dir" \
      >"$dir/stdout.json" 2>"$dir/stderr.log"
    rc=$?
  fi
  t1=$(date +%s%N)
  echo "$model $tag $mode $t0 $t1 $rc" >> "$OUT/timing.log"
  log "ran $model $tag $mode rc=$rc wall_ms=$(( (t1-t0)/1000000 ))"
}

log "benchmark start"
# warmup runs (discarded from stats)
run_one mistral-large-4 warm json
run_one glm-5-3 warm json
# measured runs, interleaved A/B to cancel server drift
for i in $(seq 1 $RUNS); do
  for m in $MODELS; do
    run_one "$m" "r$i" json
  done
  log "completed pair $i/$RUNS"
done
# streaming pass for time-to-first-token
run_one mistral-large-4 ttft stream
run_one glm-5-3 ttft stream
log "benchmark end"
