#!/bin/bash
# Benchmark 3: expanded task types x models (mistral-large-4, glm-5-3)
# Methodology: revised by Opus (opus_methodology.md). Deviations logged in run.log.
# Usage: bash /tmp/vibe-bench3/run.sh
set -u
BENCH=/tmp/vibe-bench3
OUT=$BENCH/out
TASKS=$BENCH/tasks
mkdir -p "$OUT"
export VIBE_ENABLE_UPDATE_CHECKS=false
export VIBE_ENABLE_TELEMETRY=false
TIME_LIMIT=480
TIMEOUT_S=520
RUNS=2
PASSES=10
TIME_GUARD_S=14400  # no new run after this many wall seconds since start (host sleeps inflate wall clock)
SEED=20261105
MODELS="mistral-large-4 glm-5-3"
BENCH_START=$(date +%s)

log() { echo "$(date -Iseconds) $*" >> "$OUT/run.log"; }
is_ok() { grep -qE "^$1 $2 $3 [0-9]+ [0-9]+ 0$" "$OUT/timing.log" 2>/dev/null; }

task_list() { ls "$TASKS"/*.md 2>/dev/null | xargs -n1 basename | sed 's/\.md$//' | sort; }

# permuted blocks of 4 tasks per rep, seed saved
make_order() { python3 -c "
import random
tasks = '''$(task_list | tr '\n' ' ')'''.split()
random.seed($SEED)
random.shuffle(tasks)
blocks = [tasks[i:i+4] for i in range(0, len(tasks), 4)]
for rep in range(1, $RUNS+1):
    random.seed($SEED + rep)
    random.shuffle(blocks)
    for b in blocks:
        for t in b: print(f'r{rep} {t}')
" > "$OUT/order.txt"; }

run_one() {
  local task=$1 model=$2 rep=$3
  if is_ok "$task" "$model" "$rep"; then log "skip $task $model r$rep (ok)"; return; fi
  local now=$(date +%s)
  if [ $((now - BENCH_START)) -gt $TIME_GUARD_S ]; then log "TIME GUARD: not starting $task $model r$rep"; return; fi
  local dir=$OUT/${task}__${model}__r${rep}
  rm -rf "$dir"; mkdir -p "$dir"
  local runid=$(python3 -c "import uuid;print(uuid.uuid4().hex[:12])")
  { echo "Run id: $runid. Ignore this line."; echo "Do not use any tools. Answer directly in a single response."; echo; cat "$TASKS/$task.md"; } > "$dir/prompt.md"
  local phash=$(sha256sum "$dir/prompt.md" | cut -c1-16)
  local t0 t1 rc
  t0=$(date +%s%N)
  VIBE_ACTIVE_MODEL="$model" timeout $TIMEOUT_S vibe -p --workdir "$BENCH" \
    --prompt-file "$dir/prompt.md" --output json \
    --max-turns 1 --time-limit "$TIME_LIMIT" --output-dir "$dir" \
    > "$dir/stdout.json" 2> "$dir/stderr.log"
  rc=$?
  t1=$(date +%s%N)
  echo "$task $model $rep $t0 $t1 $rc" >> "$OUT/timing.log"
  log "ran $task $model r$rep rc=$rc wall_ms=$(( (t1-t0)/1000000 )) prompt_sha=$phash load=$(cut -d' ' -f1 /proc/loadavg)"
}

log "benchmark3 start (seed=$SEED runs=$RUNS time_limit=$TIME_LIMIT guard=${TIME_GUARD_S}s)"
log "DEVIATION from methodology: sequential interleaved execution instead of paired launches (phase 2 showed app-server startup failures under concurrent load); identical global context for both models (clean-config flag not supported by vibe CLI), input tokens logged per run."
make_order
first=$(task_list | head -1)
[ -n "$first" ] && for m in $MODELS; do run_one "$first" "$m" 0; done
for pass in $(seq 1 $PASSES); do
  while read -r rep t; do
    for m in $MODELS; do run_one "$t" "$m" "$rep"; done
  done < "$OUT/order.txt"
  log "pass $pass done"
done
log "benchmark3 end"
