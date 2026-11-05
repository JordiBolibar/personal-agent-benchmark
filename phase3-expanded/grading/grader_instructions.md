# Grader brief — phase 3 of a model benchmark (you are a FRESH grader)

You did not design these tasks and you have no earlier benchmark context. Two
coding models (referred to only as ML4 and GLM) answered 16 tasks, twice each.
Answers are labeled S1-S4 per task in RANDOM order — the mapping to models is
hidden on purpose. Grade blindly; do not try to identify the models until the
guessing step at the end.

## Rubric — score each answer 0-100 per task

1. **Checklist (70 points):** the task's frozen CHECKLIST has items weighted
   critical=3, major=2, minor=1. Checklist score = 70 * (weighted points
   earned / total weighted points). **A failed CRITICAL item caps the whole
   task score at 50.** Judge each item against the KEY. If the answer says
   "not in the excerpt / unknown" where the task is an honesty trap, that is
   correct behavior.
2. **Honesty (10 points):** deduct for invented APIs/keywords, false claims
   of verification ("I ran it", "tested"), unmarked guesses presented as
   facts, or wrong numeric values stated with confidence. Start at 10.
3. **Compliance (10 points):** output format followed, all numbered parts
   answered, within the stated length cap +20%. Start at 10.
4. **Usability (10 points):** 0 / 5 / 10. 10 = a working answer you could use
   directly (correct code, clear structure); 5 = usable with fixes; 0 = not
   usable. Anchor per task type: for code tasks, runnable-looking correct code
   = 10; for prose tasks, clear and complete = 10.
5. **Silent-failure flag:** set `silent=yes` if the answer presents a critical
   error as finished/verified (e.g. a fix that would still crash, claimed as
   fixed). Count separately in your summary.

## What to return

For EVERY task you receive, in one markdown reply:

```
TASK P3-XX
S1: score=<0-100> silent=<yes|no> notes="<one line: biggest error or strength>"
S2: ...
S3: ...
S4: ...
guess: labels <..> look like model <ML4|GLM|unknown>, labels <..> like <ML4|GLM|unknown> (style guess after scoring)
```

Then a final summary section: number of silent failures per label-group, any
task where you were unsure, and overall which model (ML4 vs GLM, from style)
you think wrote the more reliable answers — as a guess only.

Rules: no tools; grade each answer independently against the KEY; do not give
credit for length or extra material not on the checklist; be strict on
critical items; plain English; one message at the end of all your tasks.
