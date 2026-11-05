#!/bin/bash
# Analyze benchmark 2 results: per (task, model) metrics + extracted answers.
# Usage: bash /tmp/vibe-bench2/analyze.sh
set -u
BENCH=/tmp/vibe-bench2
OUT=$BENCH/out
cd "$OUT"

# last timing line per key wins
awk '{ key=$1" "$2" "$3; line[key]=$0 } END { for (k in line) print line[k] }' timing.log > timing_last.log

while read -r task model rep t0 t1 rc; do
  d="${task}__${model}__r${rep}"
  [ -f "$d/export.json" ] || continue
  # keep only measured reps (>=1) that finished cleanly
  [ "$rep" -ge 1 ] || continue
  jq -c --arg task "$task" --arg model "$model" --arg rep "$rep" --argjson wall_ms "$(( (t1-t0)/1000000 ))" --arg rc "$rc" \
    'def ts: (sub("Z$";"") | split(".")) as $p | (($p[0] + "Z")|fromdateiso8601) + (($p[1] // "0")|tonumber/1000000);
     {task:$task, model:$model, rep:($rep|tonumber), rc:$rc, wall_ms:$wall_ms,
      internal_ms: (((.ended_at|ts)-(.started_at|ts))*1000|round),
      outcome, steps, exit_code,
      in:.usage.input_tokens, out:.usage.output_tokens, cached:.usage.cached_input_tokens}' \
    "$d/export.json" 2>/dev/null
  # extract the assistant text answer
  if [ -f "$d/stdout.json" ]; then
    jq -r '[.[] | select(.type=="message" and .role=="assistant") | .content[] | select(.type=="text") | .text] | join("\n")' \
      "$d/stdout.json" > "$BENCH/ans_${task}__${model}__r${rep}.txt" 2>/dev/null
  fi
done < timing_last.log > "$OUT/all_runs.jsonl"

jq -s -r '
  def med(a): (a|sort) as $s | (if ($s|length)%2==1 then $s[(($s|length)/2)|floor] else ($s[(($s|length)/2)-1] + $s[($s|length)/2])/2 end);
  [ .[] | select(.outcome=="finished" and .steps==1 and .exit_code==0 and .rc=="0")
         | . + {toks:(.out/(.internal_ms/1000))} ]
  | group_by(.task + "|" + .model)
  | sort_by(.[0].task, .[0].model)
  | map({key: (.[0].task + " | " + .[0].model), n: length,
         runs: map({rep, wall_s:(.internal_ms/1000|round), out, toks_per_s:(.toks*10|round/10), cached}),
         median_toks: (med([.[].toks])*10|round/10),
         median_wall_s: (med([.[].internal_ms/1000])*10|round/10),
         total_out: (map(.out)|add)})
  | .[] | "TASK \(.key)  n=\(.n)  median \(.median_toks) tok/s  median wall \(.median_wall_s)s  out_total \(.total_out)",
    (.runs[] | "    r\(.rep): \(.wall_s)s  out=\(.out)  \(.toks_per_s) tok/s  cached=\(.cached)")' \
  all_runs.jsonl
