# Modeling and Evaluation Reference

Read this file when selecting models, training, tuning hyperparameters, evaluating performance, or deciding between ML approaches.

---

## Gradient Boosted Decision Trees (Default for Tabular Data)

GBDTs remain the best default for structured/tabular prediction. Use this decision logic:

### Which GBDT?
```
Default → XGBoost (strongest community, most reliable, best documented)
Dataset > 1M rows → LightGBM (leaf-wise growth, GOSS + EFB = fastest training)
Heavy categorical features + want minimal preprocessing → CatBoost (native cat handling, fastest inference: 30-60x faster)
After Optuna tuning → all three perform similarly; pick based on ecosystem fit
```

### GBDT Hyperparameter Tuning (Optuna)
Always tune these parameters. Use log-scale for learning rate and regularization:
```python
# Optuna search space for XGBoost/LightGBM
learning_rate: log_uniform(0.005, 0.3)      # most impactful
max_depth: int(3, 12)                         # 6 is good default
n_estimators: int(100, 3000)                  # use early stopping instead
min_child_weight: int(1, 300)                 # regularization
subsample: uniform(0.5, 1.0)                  # row sampling
colsample_bytree: uniform(0.3, 1.0)          # column sampling
reg_alpha: log_uniform(1e-8, 10.0)           # L1
reg_lambda: log_uniform(1e-8, 10.0)          # L2
```
Use `HyperbandPruner` with `TPESampler`. 50-100 trials is usually sufficient. ALWAYS use early stopping on validation loss rather than fixed n_estimators.

---

## TabPFN (Foundation Model for Small-Medium Tabular Data)

TabPFN 2.5 is a transformer pre-trained on ~130M synthetic datasets. It performs classification and regression via in-context learning (no gradient-based training).

### When to Use
```
IF n ≤ 10K AND features ≤ 500 → TabPFN v2 (strong default, single forward pass)
IF n ≤ 50K AND features ≤ 2K → TabPFN 2.5 (matches tuned AutoGluon ensembles)
IF n > 50K → use GBDTs (TabPFN doesn't scale beyond this yet)
IF need production latency → use TabPFN's distillation engine to export to MLP or tree ensemble
IF need interpretability → TabPFN supports native feature importance and uncertainty
```

### Key Advantages
- Zero hyperparameter tuning required
- Built-in uncertainty quantification (calibrated probabilities)
- Handles missing values and mixed types natively
- Competitive with 4-hour AutoGluon runs in a single forward pass

---

## Deep Learning for Tabular Data

### Decision Framework
```
IF data is purely tabular + n < 1M → GBDTs beat DL in most benchmarks. Use GBDTs.
IF data is multimodal (text + tabular, image + tabular) → DL justified for joint encoding
IF n > 1M + complex feature interactions → DL may help; test FT-Transformer first
IF data has sequential structure (event logs, clickstreams) → Transformer or LSTM justified
IF deploying to edge/mobile → DL may be needed for unified serving
```

The TabReD benchmark (ICLR 2025) showed that with realistic time-based splits, simple MLPs and GBDTs show the best results while fancier DL architectures underperform. Academic benchmarks with random splits overstate DL performance on tabular data.

### Framework Selection
```
Default for research/prototyping → PyTorch (~75% of NeurIPS papers)
Need mobile/edge deployment → TensorFlow/TFLite (gold standard for edge)
Maximum performance + TPU access → JAX (4-5x speedups via JIT)
Want backend flexibility → Keras 3 (runs on PyTorch, TF, or JAX)
```

---

## AutoML

### When to Use
```
IF need quick baseline in < 5 minutes → AutoGluon (beats 80% of hand-tuned)
IF resource-constrained → FLAML (budget-aware, lightweight)
IF big data + distributed → H2O AutoML
IF need scikit-learn compatibility → Auto-sklearn
IF exploring whether ML adds value before investing → AutoML first, custom later
```

### When NOT to Use
```
Strict latency requirements → ensembles are slow; need single-model tuning
Interpretability required → AutoML ensembles are opaque; use EBM or logistic
Custom loss functions → most AutoML doesn't support them well
Domain-specific feature engineering needed → AutoML can't replace domain knowledge
```

AutoGluon with a 5-minute budget statistically outperforms all other AutoML systems given 1 hour.

---

## Evaluation Protocol

### Metric Selection
```
REGRESSION:
  Default → RMSE (penalizes large errors) + MAE (robust to outliers)
  Business metric exists → use it (e.g., dollar value of errors)
  Comparing across scales → MAPE (no zeros) or MASE (handles zeros)

CLASSIFICATION:
  Balanced classes → accuracy is fine, add F1
  Imbalanced classes → NEVER use accuracy alone
    IF ranking matters → AUC-ROC (threshold-independent)
    IF false positives costly → optimize precision
    IF false negatives costly → optimize recall
    IF need single metric for imbalanced → use Average Precision (PR-AUC)
  Probabilistic output needed → add Brier Score + calibration plot
```

### Cross-Validation Strategy
```
Default tabular → 5-fold stratified CV
Time series → Expanding window (train on all data before t, test on t to t+h)
  IF only recent history relevant → Sliding window
Grouped data (multiple obs per entity) → GroupKFold (prevent same customer in train+test)
Small dataset (n < 500) → Leave-One-Out or 10-fold CV
Hyperparameter tuning + final evaluation → Nested CV (inner for tuning, outer for estimate)
```

CRITICAL: Never report performance on data used for any model selection decisions. Use a true holdout or nested CV.

### Calibration
```
IF model outputs probabilities used for decisions → CHECK calibration
  Plot reliability diagram (predicted prob vs actual freq)
  Compute Brier score and Expected Calibration Error (ECE)
  IF poorly calibrated → apply Platt scaling (logistic) or isotonic regression
  IF tree model → isotonic regression preferred
  IF neural network → temperature scaling preferred
```

### Subgroup Analysis
```
ALWAYS evaluate on major subgroups (gender, region, platform, customer segment)
IF performance varies > 10% across subgroups → investigate and document
IF regulated domain → subgroup analysis is mandatory
```

---

## Interpretability

### Method Selection
```
Inherently interpretable (preferred when accuracy comparable):
  Tabular → EBM (InterpretML): AUC within 0.01-0.02 of XGBoost, fully glass-box
  Simple relationships → Linear/logistic regression with coefficient analysis
  Moderate complexity → Decision tree (depth ≤ 5) or rule lists

Post-hoc explanation (when black-box needed):
  Tree models → TreeSHAP (exact, fast, default choice)
  Any model → KernelSHAP (model-agnostic, slower)
  Local explanation needed → SHAP waterfall plot for individual predictions
  "What would change the outcome?" → DiCE counterfactual explanations
  Quick feature importance → permutation importance (model-agnostic, simple)
```

### SHAP Best Practices
- Use beeswarm plots for global feature importance
- Use waterfall plots for individual prediction explanations
- For classification, interpret SHAP on log-odds scale
- SHAP values are NOT causal — positive SHAP ≠ "increase this to improve outcome"
- SHAP can be adversarially fooled — don't use as sole fairness evidence
- Always choose a meaningful background/reference dataset

### Regulatory Requirements
```
IF EU market + high-risk system (healthcare, credit, hiring, law enforcement):
  → EU AI Act high-risk obligations effective August 2026
  → Require: risk management, documentation, human oversight, conformity assessment
  → Penalties: up to 7% worldwide annual revenue
  → Use EBMs or interpretable models where feasible; document SHAP for black-box

IF US banking:
  → SR 11-7 model risk management applies to all AI/ML models
  → Require: conceptual soundness review, ongoing monitoring, outcomes analysis

IF healthcare:
  → FDA requires pre-market submission for clinical decision support
  → Prioritize calibration and subgroup fairness
```

### Model Cards (document for any model going to production)
Include: intended use, training data description, evaluation metrics by subgroup, limitations, ethical considerations, update/monitoring plan.
