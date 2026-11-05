# Final review: ML4 vs GLM 5.3 (T1-T8)

**Limits of this review**
- I checked the math by hand and did not run any code.
- I graded the T7 API details from memory and the brief, not from the ODINN source.
- Only T1 has two ML4 answers. Every other score rests on one answer per model.
- Two task flaws are mine:
  - T2 does not define Γ.
  - In T7, the wording "`DiscreteVJP` (Mooncake)" may have misled both models.

## a. Scores

| Task | ML4 | GLM 5.3 | Deciding factor |
|---|---|---|---|
| T1 | 3 | 4 | Both have the correct adjoint and gradient. ML4 is weaker on boundary and margin reasoning, while GLM makes one false claim about the frozen case. |
| T2 | 3 | 5 | GLM gets the right Γ and the 2D anisotropy (nD along the slope, D across it). ML4's main Δt is 5× too small, and it treats 2D as isotropic. |
| T3 | 4 | 5 | Both pullbacks are correct. GLM has fuller cotangent handling and tests, plus a hand check that I confirmed. |
| T4 | 2 | 4 | ML4's "fixed" code should still crash with the original Zygote mutation error. GLM's Enzyme fix addresses the root cause, but it names some APIs that do not exist. |
| T5 | 4 | 5 | The numbers are correct in both. GLM is better on identifiability and on error propagation. |
| T6 | 3 | 4 | ML4 treats surface speed as mean speed and leaves n out of D. GLM gets both right but makes one wrong statement about which time scale controls. |
| T7 | 3 | 4 | GLM reasons better and is more honest about uncertainty. Both likely misread `DiscreteVJP`. |
| T8 | 5 | 5 | Both find all five errors and give a correct fix. GLM's test plan is deeper. |
| **Total** | **27/40** | **36/40** | |

## b. Most important errors

**ML4**
1. **T4, corrected code still fails:** it says a local array is safe with `ZygoteVJP`. Its code still writes `flux[i] = ...` and `x[1] = ...`, so Zygote should throw the same mutation error. This is the worst error in the benchmark because the fix looks finished.
2. **T4, invented names and bad advice:** `ForwardDiffVJP()` and `FiniteDiff()` are not `autojacvec` options as far as I know. It also suggests `BacksolveAdjoint` as more accurate, which is poor advice for a stiff problem.
3. **T2, wrong Γ in the main result:** it uses Γ = 2A(ρg)³ and gets Δt ≈ 1.8 d, not 9.1 d. It mentions the other convention in a note, but that convention is the correct one for a flux in H^(n+2).
4. **T2, wrong 2D limit:** it uses D_eff in both directions, so its 2D limit is too strict. It also says upwinding does not change the diffusion limit, but the limit becomes Δx²/(2D_eff + cΔx).
5. **T6, wrong speed and diffusivity:** it uses c = 5 × 40 without converting surface speed to mean speed. It also uses D = q/α without the factor n, although it derives that factor itself in T2.
6. **T1, margin and boundary errors:**
   - With its own H ~ x^(1/2), F_H scales as x^(1/2) and vanishes. It claims F_H diverges.
   - It says λ = 0 must be imposed, and its reason ignores that F_p vanishes at the margin.
7. **T7, weak physics claims:**
   - It says `SIA2D_A_target` has "no physics left", but that target keeps the SIA and Glen form.
   - It feeds MB into the law, which invites the error absorption it warns about in section 4.
   - It says slope goes to zero at margins, then recommends relative residuals right after saying they blow up there.
   - It is about 1000 words by my estimate, over the 700 limit.
8. **T3, smaller issues:**
   - There is no `unthunk` and no zero-cotangent handling.
   - It wrongly says that differentiating through the factorization would give an incorrect adjoint. That route is only more costly.

**GLM 5.3**
1. **T7, wrong use of `@ignore_derivatives`:** it calls this correct on the frozen MB model. MB depends on surface elevation, so a path θ → H → S → MB exists. Ignoring it silently removes the elevation feedback from the gradient.
2. **T1, false claim on the frozen case:** it says the frozen result is "nobody's exact gradient". If only the H-dependent part is frozen, with D = A·G(x,t), the result is the exact gradient of that linear problem. Its main conclusion still holds: this is only an approximation for the true problem.
3. **T4, API names:**
   - `ForwardDiffVVP`, `ForwardDiffVFP` and `AutoDiffVJP` do not appear to exist.
   - `dualcache` is an old name, as far as I recall.
   - It lists untyped globals as a defect, but its fix keeps `nn` and `st` as non-const globals. This may cause trouble with Enzyme.
4. **T6, two wrong statements:**
   - It says D < cL means diffusion sets the pace, but this conflicts with its own summary.
   - It says c → ū under sliding, but this is false for Weertman sliding, where c = (m+1)ū.
5. **T3, small false claims:**
   - It says Enzyme picks up the `rrule` automatically. Enzyme needs an explicit import.
   - It says the tridiagonal LU goes through LAPACK, but I recall a native Julia implementation.
6. **T7, mixed-up options:** it mixes `sensealg`/`optim_autoAD` with `ContinuousVJP`. It also calls the continuous adjoint inaccurate for stiff problems without support.

**Shared by both**
- **T7:** both treat `DiscreteVJP` as Mooncake differentiating the whole solver. As I recall, it is a hand-written discrete VJP, with Mooncake used only for the law part. Please check this against the source.
- **T7:** your memory notes say `target` is used only by manual adjoints. Neither model mentions this.
- **T6:** both give "A too high" with no caveat. Higher A also increases the flow into the tongue, so the sign may depend on location.
- **T1:** both use H ~ √d at margins, but real SIA margins differ. With Halfar's H ~ d^(3/7), F_H stays finite. With Vialov's H ~ d^(3/8), it diverges. So GLM's "coefficients vanish" is not general either.

## c. r1 vs r2 disagreements

Only ML4 on T1 can be compared, and both runs give the same core adjoint and gradient. They disagree on three points:

| Point | r1 | r2 | Better |
|---|---|---|---|
| Frozen adjoint | Uses D (and mentions nD as a variant) | Keeps nD, and misses the (n−1)D term | r1 |
| Advection term at H_x = 0 | Survives | Vanishes | r2 |
| Margins | F_H diverges, λ = 0 is required | Coefficients vanish, λ = 0 is not forced | r2 |

This shows that ML4's secondary reasoning is unstable between runs. Run coverage was also thin:
- Empty answers: GLM T1 r2, GLM T2 r2 and ML4 T2 r2.
- T3-T8 have no r2 export for either model.
- The cause is unknown, and it could be the harness and not the models.

## d. Verdict

**GLM 5.3 is the more reliable model for this work.** It wins or ties every task. It is strongest where your work is hardest: the factor n, 2D anisotropy, AD constraints and hand-checked results.

**Where each model fails**
- **ML4:** its core derivations are often right, but it fails on details and states wrong things with confidence. Its T4 fix is the main danger, because the code looks finished and should still crash. It is safer for a bounded derivation or a first draft than for AD code you plan to trust.
- **GLM:** it fails less often, and mostly in side claims, API names and overconfident remarks around correct main results. The T7 MB gradient error is the serious one, because it would give a silently wrong gradient and not a crash.

**Speed**

| Measure | ML4 | GLM 5.3 |
|---|---|---|
| Median output speed | 94.8 tok/s | 206.6 tok/s |
| Median wall time | 141.8 s | 219.2 s |
| Total wall time, r1 of T1-T8 | about 1055 s | about 1503 s |
| Output tokens per finished run | about 12.5k | about 37k |

GLM's higher tok/s does not mean faster answers. It writes about 3× the tokens per run, and ML4 uses about 30% less total wall time. GLM was faster only on T7 and T8. For this kind of task, I think the extra 40% of wall time is worth paying for GLM's accuracy.

**Recommendation**
- Use GLM 5.3 as the default worker for ODINN, SciML and glaciology tasks.
- Use ML4 as a cheaper second opinion on derivations.
- With either model, do not trust API names or AD fixes until they are checked against the source and a gradient test.
- Rerun T3-T8 with r2 before treating these scores as firm. Fix the T2 and T7 wording first.