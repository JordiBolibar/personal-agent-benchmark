#!/bin/bash
# Assemble /tmp/vibe-bench2/review_bundle.md for the Opus reviewer agent.
# Run AFTER the benchmark job finishes and analyze.sh has produced all_runs.jsonl.
set -u
BENCH=/tmp/vibe-bench2
OUT=$BENCH/out
BUNDLE=$BENCH/review_bundle.md

{
cat "$BENCH/review_instructions.md"
echo
echo "==================================================================="
echo "# Task set and answers"
echo

for t in $(ls "$BENCH"/tasks/*.md | xargs -n1 basename | sed 's/\.md$//' | sort); do
  echo "-------------------------------------------------------------------"
  echo "## TASK $t"
  echo "-------------------------------------------------------------------"
  cat "$BENCH/tasks/$t.md"
  echo
  for m in mistral-large-4 glm-5-3; do
    for r in 1 2; do
      d="$OUT/${t}__${m}__r${r}"
      echo "### ANSWER model=$m run=r$r"
      if [ -f "$d/export.json" ]; then
        jq -r --arg t "$t" --arg m "$m" --arg r "$r" '
          select(.task==$t and .model==$m and (.rep|tostring)==$r)
          | "metrics: outcome=\(.outcome) wall_s=\((.wall_ms/1000)|round) internal_s=\((.internal_ms/1000)|round) output_tokens=\(.out) tok_per_s=\((.out/(.internal_ms/1000)*10|round/10))"
        ' "$OUT/all_runs.jsonl" 2>/dev/null || echo "metrics: (see timing.log)"
      else
        echo "metrics: NO export.json (run missing)"
      fi
      ans="$BENCH/ans_${t}__${m}__r${r}.txt"
      if [ -s "$ans" ]; then cat "$ans"; else echo "(no answer text — run failed or empty)"; fi
      echo
    done
  done
done

echo "==================================================================="
echo "# Speed summary (median output tok/s over finished runs, all tasks)"
echo
jq -s -r '
  def med(a): (a|sort) as $s | (if ($s|length)%2==1 then $s[(($s|length)/2)|floor] else ($s[(($s|length)/2)-1] + $s[($s|length)/2])/2 end);
  [ .[] | select(.outcome=="finished" and .exit_code==0 and .rc=="0") | . + {toks:(.out/(.internal_ms/1000))} ]
  | group_by(.model)
  | map({model: .[0].model, n: length,
         median_toks_per_s: (med([.[].toks])*10|round/10),
         median_wall_s: (med([.[].internal_ms/1000])*10|round/10),
         total_out: (map(.out)|add),
         per_task: (group_by(.task) | map({task: .[0].task, median_toks: (med([.[].toks])*10|round/10), median_wall_s: (med([.[].internal_ms/1000])*10|round/10)}))})
  | .[] | "MODEL \(.model): n=\(.n) median \(.median_toks_per_s) tok/s, median wall \(.median_wall_s)s, total out \(.total_out) tok",
    (.per_task[] | "  \(.task): \(.median_toks) tok/s, \(.median_wall_s)s")' \
  "$OUT/all_runs.jsonl"
} > "$BUNDLE"

echo "bundle written: $BUNDLE ($(wc -c < "$BUNDLE") bytes)"
