---
name: data-science
description: "Use for any ML/data science modeling task: training classifiers, regressors, or clustering; feature engineering and selection; model evaluation; experiment design and A/B testing; causal inference; forecasting; recommender systems; anomaly detection; optimization; AutoML; NLP pipelines; MLOps and deployment. Triggers: 'build a model', 'predict', 'classify', 'cluster', 'recommend', 'detect anomalies', 'forecast', 'train', 'evaluate', 'SHAP', 'XGBoost', 'LightGBM', 'TabPFN', 'causal forest', 'uplift', 'experiment design', 'hyperparameter tuning', 'deploy model', 'feature store', 'embeddings', 'topic modeling', 'sentiment', 'time series', 'Prophet', 'Chronos', 'fraud detection', 'fairness', 'model card'. Do NOT use for pure EDA without modeling (data-analysis skill), ETL (data-engineering skill), or data quality checks (data-quality skill)."
---

# Data Science Skill

This skill enforces disciplined modeling practice across the full lifecycle: problem framing → method selection → feature engineering → training → evaluation → deployment. It is opinionated — defaults are chosen, deviations require justification.

## Architecture

Read the relevant reference file(s) BEFORE writing any modeling code:

| Task | Reference File |
|------|---------------|
| Model selection, training, GBDTs, deep learning, tabular modeling, AutoML, hyperparameter tuning | `references/modeling-and-evaluation.md` |
| Feature engineering, feature stores, feature selection, embeddings, NLP feature pipelines | `references/feature-engineering.md` |
| Experiment design, causal inference, A/B testing methodology, variance reduction, uplift modeling | `references/experimentation-and-causal.md` |
| Forecasting, recommender systems, anomaly detection, optimization, deployment, monitoring, fairness | `references/applied-domains.md` |

Many tasks span multiple files (e.g., "build a churn model" → modeling-and-evaluation.md + feature-engineering.md). Read all that apply.

---

## Pre-Flight Checklist (ALWAYS before modeling)

Before writing ANY modeling code, answer these. If info is missing, ask — but only what changes the approach.

### 1. Problem Type Classification
```
"Predict a number" → REGRESSION
"Predict a category" → CLASSIFICATION (binary or multiclass)
"Group similar items" → CLUSTERING
"Find unusual items" → ANOMALY DETECTION
"Rank or recommend items" → RECOMMENDATION / LEARNING TO RANK
"Predict future values of a series" → FORECASTING
"Estimate causal effect of X on Y" → CAUSAL INFERENCE
"Optimize a decision" → OPTIMIZATION
"Extract structure from text" → NLP PIPELINE
```

### 2. Data Reality Check
- **n rows**: < 1K (small data regime), 1K–50K (standard), 50K–1M (large), > 1M (scale matters)
- **Feature types**: tabular-only, text-heavy, image-heavy, multimodal, time-indexed
- **Target available?** IF no labeled target → unsupervised or self-supervised only
- **Target balance**: IF imbalance > 10:1 → plan stratified splits, class weights, or threshold tuning
- **Leakage risk**: Is any feature derived from the future or from the target? Remove immediately.

### 3. Success Criteria
- **Primary metric**: Pick ONE metric the model is optimized for. State it explicitly.
- **Guardrail metrics**: What must NOT degrade (latency, fairness, recall for critical class)?
- **Baseline**: What is the dumb benchmark? (majority class, global mean, last-value naive, random)
- **Minimum bar**: What performance makes this worth deploying vs. a business rule?

### 4. Deployment Context
```
IF model is for one-time analysis → optimize for accuracy, skip serving concerns
IF model serves real-time requests → latency budget? (ms target)
IF model runs batch predictions → frequency? freshness requirements?
IF model informs experiments → sample size? duration constraints?
IF model is regulated (finance, healthcare, hiring) → interpretability required, document everything
```

---

## Universal Model Development Workflow

### Step 1: Baseline First
ALWAYS establish baselines before any ML:
```
Regression → predict global mean (RMSE baseline), predict median (MAE baseline)
Classification → predict majority class (accuracy baseline), random (AUC = 0.5)
Forecasting → naive forecast (last value), seasonal naive
Ranking → popularity-based ranking
Anomaly detection → z-score or IQR threshold
```
IF your model doesn't beat the baseline → it's not adding value. Stop and investigate.

### Step 2: Simple Model Second
After baseline, build the simplest reasonable model:
```
Tabular regression → Ridge or Lasso regression
Tabular classification → Logistic regression
Time series → AutoETS or AutoARIMA
Text classification → TF-IDF + logistic regression
Clustering → K-Means with elbow method
```
This is your reference point. Complex models must justify their complexity by beating this.

### Step 3: Complex Model (if justified)
Only move to complex models when simple models are insufficient AND you understand why.

### Step 4: Evaluate Properly
See modeling-and-evaluation.md for full evaluation protocol.

### Step 5: Document and Deliver
Every model delivery includes: problem statement, data description, methodology, results with uncertainty, limitations, and recommended next steps.

---

## Method Selection Quick Router

For rapid routing to the right approach. Details in reference files.

### Tabular Prediction (most common)
```
n < 1K rows → TabPFN 2.5 (single forward pass, no tuning needed)
n 1K–50K → TabPFN 2.5 OR XGBoost/LightGBM (compare both)
n > 50K → XGBoost/LightGBM (default), CatBoost if heavy categoricals
Need interpretability → EBM (InterpretML) or logistic/linear regression
Need fastest iteration → AutoGluon (5 min budget beats 80% of hand-tuned)
```

### Causal Question
```
Can you randomize? → A/B test (see experimentation-and-causal.md)
Can't randomize + sharp cutoff → Regression Discontinuity
Can't randomize + treatment group + control over time → Diff-in-Diff
Can't randomize + treatment on observables → Double ML or Propensity Score
Need heterogeneous treatment effects → Causal Forest (EconML)
Geographic intervention → Synthetic Control or GeoLift
```

### Text/NLP Task
```
Classification → LLM zero-shot label → distill to lightweight classifier
Topic discovery → BERTopic (sentence-transformers → UMAP → HDBSCAN)
Semantic search/similarity → sentence-transformers embeddings + FAISS
Structured extraction → LLM with structured output schema
Sentiment → LLM zero-shot (replaces VADER/fine-tuned BERT for most uses)
```

### Time Series
```
Quick baseline → statsforecast (AutoETS, AutoARIMA)
Zero-shot (no training) → Chronos-2 or TimesFM 2.5
Cross-series patterns with exogenous features → LightGBM with lag features
Hierarchical → MinTrace reconciliation (hierarchicalforecast)
```

---

## Anti-Pattern Watchlist

Flag and correct these immediately:

- **No baseline comparison** → Model results are uninterpretable without one
- **Random train/test split on time series** → Use temporal split (everything before date T for train, after for test)
- **Evaluating on training data** → Always hold out data the model has never seen
- **Reporting accuracy on imbalanced data** → Use precision/recall/F1/AUC instead
- **Feature leakage** → Most common cause of unrealistically good results. Be paranoid.
- **Optimizing for wrong metric** → Confirm metric matches business objective before training
- **Overfitting to validation set via repeated tuning** → Use nested CV or final holdout
- **Training on future data** → Verify temporal ordering in all feature engineering
- **Ignoring class imbalance** → Adjust thresholds, use class weights, or resample
- **GPU for tabular data** → Almost never needed; XGBoost on CPU is fine for < 10M rows

---

## Pre-Delivery QA Checklist

Before delivering any model or modeling analysis:

- [ ] Baseline established and reported
- [ ] Train/validation/test splits are temporally correct (no future leakage)
- [ ] Primary metric and guardrails reported with confidence intervals
- [ ] Feature importance or SHAP analysis included
- [ ] Checked for leakage (no suspiciously perfect features)
- [ ] Evaluated on holdout the model never saw during development
- [ ] Cross-validated results reported (not single split)
- [ ] Class imbalance handled appropriately
- [ ] Model assumptions documented (for statistical models)
- [ ] Reproducibility ensured (random seeds set, versions noted)
- [ ] Limitations and failure modes documented
- [ ] IF regulated domain → interpretability analysis included, model card drafted
