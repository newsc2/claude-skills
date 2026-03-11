# Applied Domains Reference

Read this file for forecasting, recommendation systems, anomaly detection, optimization, model deployment/MLOps, monitoring, or responsible AI.

---

## Forecasting

### Model Selection
```
Quick baseline (always start here):
  → statsforecast: AutoETS, AutoARIMA (fast, hard to beat on simple series)
  → Naive: ŷ_t = y_{t-1}; Seasonal naive: ŷ_t = y_{t-season}
  IF model doesn't beat seasonal naive → it's not adding value

Zero-shot (no training, new in 2024-25):
  → Chronos-2 (Amazon): T5-based, univariate+multivariate, 250x faster than v1
  → TimesFM 2.5 (Google): 200M-param decoder-only, integrated with BigQuery
  → MOIRAI-2 (Salesforce): native multivariate, handles messy data
  Use when: no time to train, limited domain expertise, quick prototyping

ML-based (when cross-series patterns + exogenous features exist):
  → LightGBM with lag features via mlforecast (Nixtla)
  M5 competition confirmed: LightGBM dominates when many correlated series + rich features
  Feature recipe: lags (1,7,14,28), rolling means/stds (7,14,28d), calendar features, price features

Deep learning (large-scale, complex patterns):
  → NeuralProphet: 55-92% improvement over Prophet when auto-regression enabled
  → Temporal Fusion Transformers: best when interpretability + exogenous features both matter
  → N-BEATS: strong for pure univariate without exogenous features
  
Prophet → adequate for quick baselines and business-friendly decomposition only.
  No longer recommended for accuracy-critical applications.
```

### Hierarchical Forecasting
```
IF forecasts must be coherent across levels (product → category → total):
  → Reconciliation with MinTrace (generally best-performing method)
  → Tool: hierarchicalforecast (Nixtla)
  → Bottom-up is safe but loses top-level signal; top-down loses granularity
  → MinTrace optimally combines all levels
```

### Prediction Intervals
```
DEFAULT → Conformal prediction (distribution-free, finite-sample coverage guarantees)
  Adaptive Conformal Inference (ACI) adjusts for non-stationarity
  ConForME (2024): 52% narrower intervals than naive conformal

IF parametric model (ARIMA, ETS) → use built-in prediction intervals
IF LightGBM → quantile regression (alpha=0.05 and 0.95) for 90% intervals
IF foundation model (Chronos) → native probabilistic output available
```

### Evaluation
```
Primary metric → MASE (scale-independent, symmetric, handles zeros)
Also report → MAPE (if no zeros in actuals), RMSE (if outlier sensitivity matters)
ALWAYS compare against naive and seasonal naive baselines
Use temporal CV: expanding or sliding window, NEVER random split for time series
```

---

## Recommender Systems

### Architecture (Production Standard)
```
Stage 1 — Candidate Generation (billions → hundreds):
  → Two-tower model (user tower + item tower → shared embedding space)
  → ANN index for fast retrieval (FAISS, Milvus, or Pinecone)
  → Also include: popularity fallback, editorial picks, diversity injections

Stage 2 — Scoring/Ranking (hundreds → dozens):
  → Rich model: Wide & Deep, DCN v2, or DeepFM
  → Uses cross-features between user context and item attributes
  → Optimizes for primary engagement metric

Stage 3 — Re-Ranking (business logic):
  → Diversity (avoid showing same genre/category consecutively)
  → Freshness (boost new items for exploration)
  → Business rules (promote high-margin items, suppress out-of-stock)
  → Fairness (ensure provider-side equity if marketplace)
```

### Cold Start Strategies
```
New user → popularity-based + demographic features + onboarding survey
New item → content-based features (metadata, embeddings of description/image)
Both new → default to curated/editorial recommendations
LLM enhancement: generate rich item descriptions from minimal metadata for embedding
```

### Evaluation
```
Offline → Recall@K, NDCG@K, MAP@K (measure ranking quality)
Online → CTR, engagement time, conversion rate (the real test)
Interleaving → compare two algorithms within-user (much smaller sample than A/B)
  Netflix, Spotify, Airbnb, DoorDash all use interleaving for rec evaluation
```

### Vector Search Selection
```
Maximum control + research → FAISS (Meta, open-source)
Enterprise distributed → Milvus (open-source, scales to billions)
Zero-ops managed → Pinecone (easiest setup, per-query pricing)
Self-hosted performance → Qdrant (Rust-based, excellent latency)
```

---

## Anomaly Detection

### Method Selection
```
Simple univariate monitoring → z-score, IQR, rolling statistics (always start here)
General unsupervised tabular → Isolation Forest (scikit-learn, fast, no assumptions)
  Extended Isolation Forest → fixes score map inconsistencies of original
Subsequence/pattern anomalies in time series → Matrix Profile via STUMPY
Need many algorithms → PyOD (50+ detectors, 26M+ downloads)
Complex multivariate patterns → Autoencoder or VAE
Relational/graph data (fraud rings) → Graph-based methods (node2vec + clustering)

Evaluation metric → VUS-PR (Volume Under Surface of PR curve)
  NOT F1 with point-adjust — NeurIPS 2024 benchmark showed this is biased
```

### Fraud Detection Pattern
```
Feature engineering (most important):
  Transaction velocity (count in last 1h, 6h, 24h)
  Device/browser fingerprint features
  IP geolocation anomaly scores
  Amount deviation from user historical mean
  Time-of-day and day-of-week patterns

Model: XGBoost/LightGBM (outperforms DL by ~15% precision for most segments)
Architecture: ensemble stacking (tree-based + logistic regression, ~4.3% accuracy gain)
Graph features: node embeddings from buyer-seller graph (PayPal: 50% detection improvement)
```

---

## Optimization

### Tool Selection
```
Small-medium LP/MILP → PuLP with CBC solver (free, sufficient for most problems)
Constraint programming / scheduling / routing → Google OR-Tools CP-SAT (free, excellent)
Convex optimization with clean math → CVXPY (clearest syntax)
Industrial-scale (speed matters for ROI) → Gurobi or CPLEX (10-100x faster, $10K+/year)
Continuous nonlinear → scipy.optimize (free, good for moderate-size problems)
```

### ML + Optimization Integration
```
Pattern 1 — ML predicts, OR optimizes (most common, most mature):
  Demand forecast → inventory optimization
  Price elasticity model → revenue management
  Travel time prediction → vehicle routing

Pattern 2 — ML improves optimization:
  Neural networks learn branching strategies for Branch & Bound
  Surrogate models approximate expensive simulations for real-time decisions

Pattern 3 — Reinforcement learning replaces OR:
  Dynamic pricing (outperforms static LP in volatile markets)
  Real-time resource allocation
  Only justified when: environment is highly dynamic AND enough data to train RL agent
```

---

## Deployment and MLOps

### Right-Sizing (Don't Over-Engineer)
```
Solo / small team (1-5 DS):
  Tracking → MLflow (free, self-hosted)
  Serving → simple REST API (FastAPI + Docker) or Modal.com (serverless)
  Monitoring → Evidently AI (open-source)
  NO Kubernetes required

Mid-size team (5-20):
  + Orchestration → Metaflow (Netflix, simplest DX) or ZenML (portable)
  + Feature store → Feast (if real-time features needed)
  + Experiment tracking → MLflow or Weights & Biases

Enterprise (20+, regulated):
  + Feature platform → Tecton or Hopsworks
  + Serving → Triton (GPU) or KServe (Kubernetes-native)
  + Monitoring → Arize AI (fastest-growing, strong unstructured data support)
  + CI/CD → formal validation gates, model registry, approval workflows
```

### Model Serving Selection
```
LLM inference → vLLM (PagedAttention, 15x throughput improvement)
GPU-optimized traditional ML → NVIDIA Triton
Framework-agnostic + developer-friendly → BentoML
Kubernetes-native with scale-to-zero → KServe
Batch predictions + simple → scheduled script with MLflow model loading
```

### Monitoring Checklist
```
ALWAYS monitor after deployment:
- [ ] Prediction distribution shift (compare to training baseline)
- [ ] Feature distribution shift (same features, different distributions)
- [ ] Prediction latency (P50, P95, P99)
- [ ] Error rates and failure modes
- [ ] Business metric impact (does model performance match business outcomes?)
- [ ] Subgroup performance stability

IF distribution shift detected → trigger retraining pipeline or alert
IF business metric degrades but model metrics stable → feature or upstream data changed
```

---

## Responsible AI

### Fairness Assessment Protocol
```
1. Define protected attributes (race, gender, age, disability status, etc.)
2. Choose fairness metric based on context:
   IF equal error rates needed → Equalized Odds
   IF equal positive rates needed → Demographic Parity
   IF equal prediction accuracy needed → Calibration within groups
   NOTE: cannot satisfy all three simultaneously (impossibility theorem)
   
3. Measure: use Fairlearn dashboards or AIF360
4. IF disparities found → mitigate:
   Pre-processing: reweighing, disparate impact removal
   In-processing: adversarial debiasing, Fairlearn exponentiated gradient
   Post-processing: threshold adjustment per group
5. Document tradeoffs: what fairness metric was chosen and why
```

### Privacy-Preserving ML
```
IF need aggregate statistics without individual exposure → Differential Privacy (OpenDP, Google DP lib)
IF data can't leave source (hospitals, banks) → Federated Learning (Flower, NVIDIA FLARE)
IF need to verify model was trained on authorized data → data provenance tracking
Privacy budget (ε): smaller ε = more privacy but less utility. Typical: ε = 1-10 for practical ML.
```

### Model Governance Checklist
```
- [ ] Model card documenting intended use, limitations, and performance by subgroup
- [ ] Training data documented (source, size, collection process, known biases)
- [ ] Fairness metrics computed and documented
- [ ] Human oversight mechanism defined (who reviews model decisions?)
- [ ] Update/retraining schedule defined
- [ ] Rollback plan documented (how to revert if model misbehaves)
- [ ] IF EU market → EU AI Act compliance review (high-risk obligations August 2026)
- [ ] IF US banking → SR 11-7 model risk management documentation
```
