# Experimentation and Causal Inference Reference

Read this file when designing experiments, analyzing A/B tests, performing causal inference, or building uplift models.

---

## Experiment Design Decision Tree

### Step 1: Can You Randomize?
```
IF yes + individual-level treatment possible → Standard A/B test
IF yes + but network/marketplace effects exist → Switchback or cluster-randomized design
IF yes + multiple variants to test → Multi-arm test with Bonferroni/Holm correction
IF no → Quasi-experimental design (see Causal Inference section below)
```

### Step 2: Choose Testing Framework
```
DEFAULT → Sequential testing (always-valid confidence sequences)
  - Maintains coverage at any stopping time
  - Allows early stopping for clear winners/losers
  - Netflix standard: catches regressions in days, not weeks

IF precise effect size estimate required → Fixed-horizon test
  - Pre-commit to sample size and duration
  - Do NOT peek (inflates false positive from 5% to 20-30%)

IF high opportunity cost of showing inferior variant → Multi-armed bandit
  - Thompson Sampling (Bayesian) or UCB (frequentist)
  - Trades off estimation precision for cumulative reward
  - NOT appropriate when you need precise lift estimates

IF want probability statements ("85% chance B is better") → Bayesian A/B test
  - Intuitive interpretation, continuous monitoring without penalty
  - Requires prior specification (weakly informative default: Beta(1,1))
```

### Step 3: Power Analysis
```
BEFORE launching, calculate required sample size:
  Inputs needed: baseline metric, minimum detectable effect (MDE), α=0.05, power=0.80
  
  Rule of thumb for proportions:
    n_per_group ≈ 16 × (baseline × (1-baseline)) / MDE²
  
  IF calculated duration > acceptable → apply variance reduction (see below)
  IF calculated n > available traffic → increase MDE or use more sensitive metric
  IF testing rare event (< 1% rate) → need very large samples; consider proxy metrics
```

---

## Variance Reduction Techniques

### CUPED (Controlled-experiment Using Pre-Experiment Data)
```
WHAT: Regress out predictable component using pre-experiment covariates
HOW:  Ŷ_cuped = Y - θ(X - E[X]) where θ = Cov(Y,X)/Var(X)
EFFECT: Typically 30-50% variance reduction → experiments conclude 40-65% faster

WHEN TO USE:
  IF pre-experiment data available for same metric → always use CUPED
  IF pre-experiment data available for correlated metric → use as covariate
  IF no pre-experiment data → cannot use CUPED

IMPLEMENTATION:
  Platforms with built-in CUPED: Statsig, Eppo/Datadog, GrowthBook (manual setup)
  Manual: compute theta from pre-period, adjust treatment/control means
```

### ML-Augmented Variance Reduction
```
IF linear CUPED gives < 10% reduction → try ML-augmented approaches:
  CUPAC (DoorDash): use ML predictions as covariates instead of raw pre-period data
  ML-CUPED: train model on pre-period features to predict outcome, use residuals

Airbnb progression:
  Linear CUPED → ~5% variance reduction on bookings
  ML-augmented CUPED → ~15%
  In-experiment surrogates → 50-85% variance reduction
```

---

## Experiment Analysis Checklist

### Pre-Analysis (before looking at results)
```
1. Confirm sample ratio mismatch (SRM) test passes
   - Chi-squared test on variant group sizes
   - IF SRM detected → results are INVALID, investigate randomization bug
   - Common causes: bot filtering, redirect failures, session counting errors

2. Confirm pre-experiment balance
   - Key covariates should be balanced across variants (CUPED check)
```

### Analysis
```
3. Compute: lift %, confidence interval, p-value, sample size per variant
4. Apply CUPED adjustment if pre-experiment data available
5. Check primary metric + ALL guardrail metrics
6. Segment analysis: break by platform, user type, geography, tenure
   - IF heterogeneous effects → report segments separately
   - IF Simpson's paradox → report segment-level as primary
```

### Post-Analysis
```
7. Statistical vs practical significance:
   - IF p < 0.05 but lift < MDE → statistically significant but not practically meaningful
   - IF p > 0.05 but CI excludes meaningful negative effects → safe to ship (underpowered, not harmful)
   
8. Document: hypothesis, design, duration, results, decision, learnings
9. IF shipping variant → set up long-term holdout (1-5%) for delayed effects
```

---

## Causal Inference Methods (When Randomization Is Not Possible)

### Method Selection
```
Sharp eligibility cutoff (age 65, score threshold, date boundary):
  → Regression Discontinuity Design (RDD)
  Bandwidth: use Imbens-Kalyanaraman optimal bandwidth
  Validity: test for manipulation at cutoff (McCrary density test)
  Report: local average treatment effect (LATE) at cutoff

Treatment + control groups observed over time:
  → Difference-in-Differences (DiD)
  CRITICAL: test parallel trends assumption (pre-treatment trends must be parallel)
  IF staggered rollout (different groups treated at different times):
    → Use Callaway-Sant'Anna or Sun-Abraham estimator (NOT two-way FE)
    Classic TWFE is biased with staggered treatment — this is now well-established
  Tool: Python `differences` package or R `did` package

Treatment assigned based on observable characteristics:
  → Double/Debiased ML (preferred) or Propensity Score methods
  Double ML: use ML for nuisance estimation + cross-fitting for valid inference
  Tool: EconML DoubleML or LinearDML
  Propensity Score: IF overlap is poor → IPW is unreliable; try matching or trimming

Single treated unit + donor pool of controls:
  → Synthetic Control Method
  Tool: Meta's GeoLift (for marketing geo-experiments) or SparseSC
  Validity: pre-treatment fit must be excellent; run placebo tests on donors

Need an instrument (exogenous variation affecting treatment but not outcome directly):
  → Instrumental Variables / 2SLS
  Test: first-stage F-statistic > 10 (weak instrument check)
  IF F < 10 → instrument is too weak, results unreliable
```

### Heterogeneous Treatment Effects
```
IF need to know WHO benefits most from treatment:
  → Causal Forest (grf package in R, EconML in Python)
  Splits on treatment effect heterogeneity, not outcome prediction
  Use for: personalized targeting, optimal treatment assignment

IF need uplift model for marketing:
  → CausalML (Uber): T-learner, S-learner, X-learner, DragonNet
  Decision: X-learner for unequal treatment/control sizes, T-learner as default

IF need Double ML + heterogeneity:
  → EconML LinearDML with interaction terms or CausalForestDML
```

---

## Causal Inference Anti-Patterns
```
Conditioning on post-treatment variables → collider bias (blocks true effect)
Claiming causation from observational correlation without design → always state assumptions
Using TWFE with staggered treatment → known to produce biased estimates, use modern estimators
Ignoring positivity violations → if P(treatment | X) ≈ 0 or 1 for some X, trim those observations
Not reporting sensitivity to unobserved confounding → always provide E-values or Rosenbaum bounds
Running causal analysis without DAG → draw the causal graph first, identify adjustment sets
```

---

## Experimentation Platforms

### Selection Guide
```
Full-featured + free tier + sequential testing → Statsig (founded from Facebook, used by OpenAI)
Warehouse-native + contextual bandits → Eppo/Datadog (founded from Airbnb culture)
Open-source + self-hosted → GrowthBook (good community, manual CUPED setup)
Enterprise + existing analytics stack → LaunchDarkly (feature flags focus) or Amplitude Experiment
Build your own → only if you have 5+ experimentation engineers and unique requirements
```

### Platform Requirements Checklist
```
- [ ] Sequential testing support (not just fixed-horizon)
- [ ] CUPED or variance reduction built in
- [ ] SRM detection automated
- [ ] Segment analysis built in
- [ ] Guardrail metric support
- [ ] Warehouse integration (reads from your data, not just SDK events)
- [ ] Audit trail for experiment decisions
```
