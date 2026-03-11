# EDA and Statistical Methods Reference

Read this file when performing exploratory data analysis, statistical testing, A/B test analysis, regression, time series, forecasting, attribution, or causal inference.

---

## EDA: Nine-Phase Workflow

Execute these phases in order. Each has explicit decision branches.

### Phase 1: Shape & Structure
Check row counts, column counts, data sources, time range, grain (what does one row represent?). Flag: unexpectedly small/large datasets, mixed sources without labels.

### Phase 2: Schema Sanity
Verify data types match expected types. IF IDs stored as floats → convert to string. IF dates stored as strings → parse to datetime. IF numeric column has non-numeric entries → investigate before coercing.

### Phase 3: Missingness
```
IF missing rate < 5% → Listwise deletion generally safe
IF missing rate 5-30% → Impute:
  - Mean/median for MCAR (missing completely at random)
  - KNN or MICE for MAR (missing at random)
IF missing rate > 50% → Consider dropping column, BUT:
  - IF missingness itself is informative → create binary _is_missing flag
  - IF structural "not applicable" → fill with "None" category
IF missingness correlates with target variable → keep as flag feature
```

### Phase 4: Duplicates
IF exact duplicates → remove (keep first). IF near-duplicates → investigate source. IF duplicate rate > 1% → investigate pipeline root cause before proceeding.

### Phase 5: Target Integrity
IF class imbalance > 10:1 → plan stratified sampling or resampling. IF target has 100+ unique values → treat as regression. IF any feature correlates > 0.95 with target → investigate data leakage immediately.

### Phase 6: Distributions
IF skewness > |2| → consider log or Box-Cox transform. IF impossible values present → flag as data quality error. IF categorical variable has single category > 99% → near-zero variance, consider dropping.

### Phase 7: Outliers
```
STEP 1 — DETECT using IQR (< Q1-1.5×IQR or > Q3+1.5×IQR) or Modified Z-score (|mz| > 3.5)

STEP 2 — INVESTIGATE:
  Data entry/measurement error → Correct or REMOVE
  Pipeline/processing error → Fix pipeline
  Genuine extreme value → Step 3
  Unknown cause → Flag, DO NOT auto-remove

STEP 3 — DECIDE by downstream use:
  Linear regression, KNN, SVM → High impact → Treat (winsorize or transform)
  Tree-based models → Low impact → Safe to keep
  Computing mean/std → Distorts → Use median/IQR or robust methods
  
TREATMENT OPTIONS (in order of preference):
  1. Keep + use robust methods (RobustScaler, Huber regression, median)
  2. Winsorize at 1st/99th percentile
  3. Log transform (if all values > 0 and right-skewed)
  4. Create is_outlier flag (if outlier status is informative)
  5. Remove ONLY IF: confirmed error + small count + documented reason
```

Governing principle: Run analysis with AND without outliers. If conclusions change substantially, you cannot drop them without justification.

### Phase 8: Relationships
IF Pearson r between features > 0.9 → flag multicollinearity. IF VIF > 10 → severe multicollinearity. IF correlation ≈ 1.0 → suspect leakage or derived feature. Use Pearson for linear/normal, Spearman for monotonic/ordinal, Cramér's V for categorical.

### Phase 9: Leakage Scan
Check for features encoding future information. IF timestamps or outcomes from after prediction time → remove immediately. This is the most common and most damaging analytical error.

### EDA Completion Criteria
EDA is done when: every column has documented meaning/unit/valid range, data types verified, missingness quantified with handling strategy, duplicates resolved, outlier decisions documented, key relationships examined, no leakage features remain, and new visualizations confirm what you already know rather than revealing new patterns.

---

## Statistical Test Selection

### Comparing Groups
```
2 independent groups:
  Continuous + normal → Welch's t-test (default over Student's t)
  Ordinal or non-normal → Mann-Whitney U
  Categorical → Chi-squared (Fisher's exact if expected cell count < 5)

2 paired/dependent groups:
  Continuous + normal → Paired t-test
  Ordinal or non-normal → Wilcoxon signed-rank
  Categorical → McNemar test

3+ independent groups:
  Continuous + normal → One-way ANOVA + Tukey's HSD post-hoc
  Ordinal or non-normal → Kruskal-Wallis
  Categorical → Chi-squared
```

### Testing Relationships
```
Both continuous + normal → Pearson correlation
Both continuous, non-normal → Spearman rank correlation
Both categorical → Chi-squared test of independence
```

### Predicting Outcomes
```
DV continuous → Linear/multiple regression
DV binary → Logistic regression
DV ordinal → Ordinal logistic regression
```

### Assumption Checks (run before choosing test)
- Normality: Shapiro-Wilk (n < 50) or visual QQ-plot. IF p > 0.05 → assume normal.
- Equal variance: Levene's test. IF p > 0.05 → equal variance met.
- IF n < 30 AND non-normal → use nonparametric alternative.
- For multiple comparisons: apply Benjamini-Hochberg (preferred) or Bonferroni correction.

### Always Report
- Effect size (Cohen's d: 0.2=small, 0.5=medium, 0.8=large) alongside p-values
- Confidence intervals
- Sample sizes per group
- Practical significance, not just statistical significance

---

## A/B Testing

### Pre-Experiment
1. State hypothesis clearly: "[Change X] will [increase/decrease] [metric Y] by [minimum Z%]"
2. Calculate required sample size given: baseline rate, MDE, significance level (0.05), power (0.80)
3. Pre-commit to decision rules: "IF p < 0.05 AND lift > [MDE], ship variant B"
4. Define primary metric AND guardrail metrics (counter-metrics to watch for negative side effects)

### During Experiment
- Do NOT peek at results repeatedly (inflates false positive rate from 5% to 20-30%)
- IF peeking required → use sequential testing (Group Sequential, Always Valid Inference, or Confidence Sequences)
- Check for sample ratio mismatch (SRM) — if variant group sizes differ more than expected by chance, something is wrong with randomization

### Post-Experiment
1. Check SRM first — if present, results are unreliable
2. Report: lift %, confidence interval, p-value, sample size per variant
3. Check segment effects (don't just report overall — break by platform, user type, etc.)
4. Distinguish statistical significance from practical significance
5. Document: hypothesis, design, results, decision taken, learnings

### Variance Reduction
CUPED (Controlled-experiment Using Pre-Existing Data) uses pre-experiment covariates to reduce variance, potentially cutting required sample sizes by 50%+. Formula: Ŷ_cuped = Y - θ(X - E[X]).

---

## Regression

### Linear Regression Assumptions (LINE)
- **L**inearity: residual plots should show no pattern
- **I**ndependence: no autocorrelation (Durbin-Watson ≈ 2)
- **N**ormality of residuals: QQ-plot, Shapiro-Wilk
- **E**qual variance: residuals vs fitted plot should show constant spread
- VIF > 5 → multicollinearity concern. VIF > 10 → severe.

### Logistic Regression
- Interpret via odds ratios: exp(β)
- Use ROC-AUC for discrimination, calibration plots for reliability
- Regularization: Lasso (L1) for feature selection, Ridge (L2) for multicollinearity, Elastic Net for both

---

## Time Series & Forecasting

### Decomposition
Use STL (Seasonal-Trend using Loess) as default — handles any seasonality type, robust to outliers. Identify: trend, seasonal pattern, residual.

### Model Selection
```
IF strong seasonality + holidays + missing data → Prophet
IF need automated model selection → auto_arima (pmdarima)
IF simple trend + seasonality, fast computation needed → Holt-Winters
IF complex patterns, large dataset → LightGBM with lag features
```

### Critical Practice
ALWAYS benchmark against naive forecasts:
- Naive: ŷ_t = y_{t-1}
- Seasonal naive: ŷ_t = y_{t-season}
These are surprisingly hard to beat. If your model doesn't beat them, it's not adding value.

### Accuracy Metrics
Prefer MASE (Mean Absolute Scaled Error) — scale-independent, symmetric, handles zeros. Also report MAPE (if no zeros) and RMSE (if outlier sensitivity matters).

---

## Attribution Modeling

```
Rule-based (simple, arbitrary):
  First-touch → credits acquisition channel
  Last-touch → credits closing channel
  Linear → equal credit to all touchpoints
  Time-decay → more credit to recent touchpoints
  Position-based → 40/20/40 to first/middle/last

Data-driven (preferred):
  Markov chains → models state transitions, calculates removal effects
  Shapley values → average marginal contribution across all permutations (used by GA4)
  Media Mix Modeling → aggregate, privacy-friendly, cross-channel (Meta Robyn, Google Meridian)
```

Calibrate models with incrementality testing (geo-holdout experiments) for ground truth.

---

## Causal Inference (when experiments aren't possible)

```
IF sharp assignment cutoff exists → Regression Discontinuity
IF treatment group + comparable control over time → Difference-in-Differences
  (requires parallel trends assumption — test it)
IF treatment assigned based on observables → Propensity Score Matching
IF endogeneity problem + valid instrument → Instrumental Variables
IF single treated unit + donor pool → Synthetic Control
```

Key references: Cunningham's *Causal Inference: The Mixtape* (free online), Huntington-Klein's *The Effect* (free online).

---

## Common Business Analysis Frameworks

Use these for structuring specific types of business analysis:

- **Cohort analysis**: Group by acquisition date, track behavior over time. Reveals retention trends hidden in aggregates.
- **AARRR (Pirate Metrics)**: Acquisition → Activation → Retention → Referral → Revenue. Fix leaks (activation/retention) before scaling acquisition.
- **RFM segmentation**: Score customers on Recency, Frequency, Monetary value. Creates segments like Champions (5-5-5), At Risk (low R, high F/M).
- **CLV**: Simple = AOV × Frequency × Lifespan. Probabilistic = BG/NBD + Gamma-Gamma model for non-contractual.
- **Funnel analysis**: Conversion rates at each step. Focus on largest absolute drop-offs, not just lowest rates.
- **SaaS Quick Ratio**: (New MRR + Expansion) / (Churned + Contraction). 4+ = healthy growth.
