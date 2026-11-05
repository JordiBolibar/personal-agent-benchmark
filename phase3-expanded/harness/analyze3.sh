#!/bin/bash
# Analyze benchmark 3: per-run results.csv + per-task summary + answer extraction.
# Usage: bash /tmp/vibe-bench3/analyze3.sh
set -u
BENCH=/tmp/vibe-bench3
OUT=$BENCH/out
cd "$OUT"

awk '{ key=$1" "$2" "$3; line[key]=$0 } END { for (k in line) print line[k] }' timing.log > timing_last.log

# results.csv: task,model,rep,rc,wall_ms,internal_ms,outcome,exit_code,in,out,cached,chars,status
while read -r task model rep t0 t1 rc; do
  repn=$(echo "$rep" | tr -cd '0-9')
  d="${task}__${model}__r${rep}"
  [ -f "$d/export.json" ] || { echo "$task,$model,$repn,$rc,$(( (t1-t0)/1000000 )),,,,,,,,,missing_export" >> results.csv; continue; }
  jq -r --arg task "$task" --arg model "$model" --arg rep "$repn" --argjson wall_ms "$(( (t1-t0)/1000000 ))" --arg rc "$rc" '
    def ts: (sub("Z$";"") | split(".")) as $p | (($p[0] + "Z")|fromdateiso8601) + (($p[1] // "0")|tonumber/1000000);
    {task:$task, model:$model, rep:($rep|tonumber), rc:$rc, wall_ms:$wall_ms,
     internal_ms: (((.ended_at|ts)-(.started_at|ts))*1000|round),
     outcome, exit_code, steps,
     inn:.usage.input_tokens, out:.usage.output_tokens, cached:.usage.cached_input_tokens}
    | [.task,.model,.rep,.rc,.wall_ms,.internal_ms,.outcome,.exit_code,.inn,.out,.cached] | @csv' \
    "$d/export.json" 2>/dev/null >> results_raw.csv
  ans="$BENCH/ans_${task}__${model}__r${repn}.txt"
  if [ -f "$d/stdout.json" ]; then
    jq -r '[.[] | select(.type=="message" and .role=="assistant") | .content[] | select(.type=="text") | .text] | join("\n")' \
      "$d/stdout.json" > "$ans" 2>/dev/null
    echo "$task,$model,$repn,$rc,$(( (t1-t0)/1000000 )),$(jq -r '(((.ended_at|sub("Z$";"")|split(".")) as $p | (($p[0]+"Z")|fromdateiso8601)+((($p[1]//"0")|tonumber)/1000000)) - ((.started_at|sub("Z$";"")|split(".")) as $q | (($q[0]+"Z")|fromdateiso8601)+((($q[1]//"0")|tonumber)/1000000))) * 1000 | round)' "$d/export.json" 2>/dev/null),$(jq -r '.outcome' "$d/export.json"),$(jq -r '.exit_code' "$d/export.json"),$(jq -r '.usage.input_tokens' "$d/export.json"),$(jq -r '.usage.output_tokens' "$d/export.json"),$(jq -r '.usage.cached_input_tokens' "$d/export.json"),$(wc -c < "$ans" 2>/dev/null || echo 0)" >> results.csv
  fi
done < timing_last.log

echo "task,model,rep,rc,wall_ms,internal_ms,outcome,exit_code,in_tok,out_tok,cached_tok,answer_chars" > results_header.csv
cat results_header.csv results.csv > results_full.csv

# per-task summary for measured reps (rep>=1, rc==0, finished)
python3 - <<'EOF'
import csv, statistics, collections
rows = list(csv.DictReader(open('results_full.csv')))
ok = [r for r in rows if int(r['rep']) >= 1 and r['rc'] == '0' and r['outcome'] == 'finished']
by = collections.defaultdict(list)
for r in ok:
    wall_s = int(r['wall_ms']) / 1000
    out = int(r['out_tok'] or 0)
    chars = int(r['answer_chars'] or 0)
    by[(r['task'], r['model'])].append((wall_s, out, chars, out / wall_s if wall_s else 0, chars / wall_s if wall_s else 0))
print("task | model | n | wall_s med (min-max) | out_tok med | tok/s med | chars/s med")
for (t, m), v in sorted(by.items()):
    walls = [x[0] for x in v]; outs = [x[1] for x in v]; tokses = [x[3] for x in v]; cps = [x[4] for x in v]
    med = lambda a: statistics.median(a)
    print(f"{t} | {m} | {len(v)} | {med(walls):.0f} ({min(walls):.0f}-{max(walls):.0f}) | {med(outs):.0f} | {med(tokses):.1f} | {med(cps):.1f}")
# first-try valid rate per model (rep 1 only, all tasks)
print()
print("first-try valid rate (rep1, rc==0 & finished):")
for m in ('mistral-large-4', 'glm-5-3'):
    r1 = [r for r in rows if r['model'] == m and r['rep'] == '1']
    valid = [r for r in r1 if r['rc'] == '0' and r['outcome'] == 'finished']
    print(f"  {m}: {len(valid)}/{len(r1)}")
EOF
