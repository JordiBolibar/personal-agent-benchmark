#!/bin/bash
# Benchmark 2: varied tasks (designed by Opus 5.5) x models (mistral-large-4, glm-5-3)
# Usage: bash /tmp/vibe-bench2/run.sh
set -u
BENCH=/tmp/vibe-bench2
OUT=$BENCH/out
TASKS=$BENCH/tasks
mkdir -p "$OUT"
export VIBE_ENABLE_UPDATE_CHECKS=false
export VIBE_ENABLE_TELEMETRY=false
TIME_LIMIT=600
RUNS=2
PASSES=3
MODELS="mistral-large-4 glm-5-3"

log() { echo "$(date -Iseconds) $*" >> "$OUT/run.log"; }

# ok if a timing line exists for key with rc==0
is_ok() { grep -qE "^$1 $2 $3 [0-9]+ [0-9]+ 0$" "$OUT/timing.log" 2>/dev/null; }

run_one() {
  local task=$1 model=$2 rep=$3
  if is_ok "$task" "$model" "$rep"; then log "skip $task $model r$rep (ok)"; return; fi
  local dir=$OUT/${task}__${model}__r${rep}
  rm -rf "$dir"; mkdir -p "$dir"
  { echo "Do not use any tools. Answer directly in a single response."; echo; cat "$TASKS/$task.md"; } > "$dir/prompt.md"
  local t0 t1 rc
  t0=$(date +%s%N)
  VIBE_ACTIVE_MODEL="$model" timeout 640 vibe -p --workdir "$BENCH" \
    --prompt-file "$dir/prompt.md" --output json \
    --max-turns 1 --time-limit "$TIME_LIMIT" --output-dir "$dir" \
    > "$dir/stdout.json" 2> "$dir/stderr.log"
  rc=$?
  t1=$(date +%s%N)
  echo "$task $model $rep $t0 $t1 $rc" >> "$OUT/timing.log"
  log "ran $task $model r$rep rc=$rc wall_ms=$(( (t1-t0)/1000000 ))"
}

task_list() { ls "$TASKS"/*.md 2>/dev/null | xargs -n1 basename | sed 's/\.md$//' | sort; }

log "benchmark2 start"
# one warmup run per model on the first task (rep 0, excluded from stats)
first=$(task_list | head -1)
[ -n "$first" ] && for m in $MODELS; do run_one "$first" "$m" 0; done
# measured runs, interleaved: rep -> task -> model, with retry passes
for pass in $(seq 1 $PASSES); do
  for t in $(task_list); do
    for r in $(seq 1 $RUNS); do
      for m in $MODELS; do
        run_one "$t" "$m" "$r"
      done
    done
  done
  log "pass $pass done"
done
log "benchmark2 end"
