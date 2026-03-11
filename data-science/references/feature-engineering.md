# Feature Engineering Reference

Read this file when building features, selecting features, working with feature stores, generating embeddings, or building NLP feature pipelines.

---

## Feature Engineering Workflow

### Pre-Flight
```
1. What is the prediction target and at what grain? (one row = one what?)
2. What is the temporal cutoff? (features must only use data available at prediction time)
3. What feature types exist? (numeric, categorical, text, datetime, geospatial)
4. Is real-time serving needed? (determines batch vs streaming feature computation)
```

### Phase 1: Temporal Features (IF datetime columns exist)
```
Extract: hour, day_of_week, month, quarter, is_weekend, is_holiday
Cyclical encoding: sin/cos for hour (hour_sin = sin(2π × hour/24))
Lag features: y_{t-1}, y_{t-7}, y_{t-30} (match business cadence)
Rolling aggregates: rolling_mean_7d, rolling_std_30d, rolling_min/max
Time since event: days_since_last_purchase, hours_since_last_login
CRITICAL: All temporal features must respect the prediction time boundary. No future leakage.
```

### Phase 2: Numeric Features
```
IF skewed (skewness > |2|) → log1p transform (handles zeros)
IF different scales + using distance-based model (KNN, SVM, neural net) → StandardScaler
IF different scales + using tree model → no scaling needed
IF meaningful ratios exist → create them (revenue_per_user, cost_per_click)
IF domain knowledge suggests interactions → create them (price × quantity)
IF polynomial relationships suspected → create degree-2 terms for top features only
```

### Phase 3: Categorical Features
```
IF cardinality ≤ 10 → one-hot encoding (default)
IF cardinality 10–100 → target encoding with CV fold regularization
IF cardinality > 100 → target encoding OR embedding (if DL)
IF using CatBoost → pass raw categories (native handling is best)
IF using XGBoost/LightGBM → target encoding preferred over one-hot for high cardinality
IF ordinal (size: S/M/L, education levels) → ordinal encoding preserving order
IF rare categories (< 1% of data) → group into "Other"
```

### Phase 4: Text Features
```
IF text is a minor feature alongside tabular → embedding approach:
  Default → sentence-transformers all-MiniLM-L6-v2 (fast, 384-dim, CPU-friendly)
  Best quality → NV-Embed-v2 (top MTEB scores, but non-commercial license)
  Multilingual → BGE-M3 (100+ languages, MIT license)
  Reduce dims if needed → PCA to 50-100 components

IF text IS the primary signal → see NLP pipeline section below

IF simple keyword signal → TF-IDF with max_features=5000-10000
```

### Phase 5: Interaction and Cross Features
```
IF domain expertise suggests interaction → create explicitly (feature_A × feature_B)
IF high-cardinality categoricals interact → create combined category (city_device_type)
IF no domain knowledge → let tree models learn interactions (don't manually create all pairs)
```

---

## Automated Feature Engineering

### Tool Selection
```
Default for tabular → OpenFE (ICML 2023, beats 99.3% of Kaggle competitors)
Multi-table relationships → Featuretools Deep Feature Synthesis
Emerging (2025) → LLM-FE: uses LLMs as evolutionary optimizers for semantically meaningful features
Time series features → tsfresh (automated extraction of 800+ features per series)
```

### OpenFE Workflow
```
1. Install: pip install openfe
2. Generate candidates: openfe.transform(X_train, y_train, n_jobs=-1)
3. Filter by importance: keep features with gain > 0 on validation set
4. Validate: re-run CV with new features, confirm improvement > noise
5. Document: which transforms were applied and why they help
```

---

## Feature Selection

### Three-Stage Funnel
```
STAGE 1 — Quick Filter (remove obvious noise):
  Remove zero-variance features
  Remove features with > 95% single value
  IF n_features > 1000 → mutual information filter, keep top 200-500

STAGE 2 — Model-Based Selection (default: BorutaSHAP):
  BorutaSHAP combines Boruta shadow features + TreeSHAP importance
  Achieves 80–99.5% accuracy across benchmarks
  Run: BorutaSHAP(model=XGBClassifier(), importance_measure='shap')
  Keep features marked 'Confirmed', investigate 'Tentative'

STAGE 3 — Validation:
  Compare CV performance: all features vs selected features
  IF performance drops > 1% → add back removed features incrementally
  Check for correlated feature pairs (r > 0.9) — keep the one with higher SHAP
```

### Alternative Selection Methods
```
IF need sparsity + interpretability → Lasso (L1) regularization
IF need fast screening of 10K+ features → mutual information
IF need recursive elimination → RFECV with cross-validation
IF features are grouped (gene sets, feature families) → group lasso
```

---

## Feature Stores

### Decision Framework
```
IF no real-time features needed + small team → skip feature store, use versioned parquet files
IF real-time features needed + budget-sensitive → Feast (open source, pluggable backends)
IF enterprise scale + real-time + budget exists → Tecton (built by Uber Michelangelo team)
IF regulated industry + need governance → Hopsworks (10x lower latency than cloud-native stores)
IF committed to single cloud:
  AWS → SageMaker Feature Store
  GCP → Vertex AI Feature Store
  Azure → Azure ML Feature Store
  Databricks → Databricks Feature Store (best Lakehouse integration)
```

### Feature Store Anti-Patterns
```
Building a feature store before you have 3+ models in production → premature
Different code paths for training vs serving features → training/serving skew
No point-in-time correctness enforcement → temporal leakage
Feature definitions without documentation/ownership → governance failure
Storing raw data as "features" → feature stores are for transformed, reusable features
```

### Training/Serving Consistency (Critical)
```
ALWAYS use the same code path for training and serving feature computation.
IF batch training + real-time serving → compute features identically in both paths
Test for skew: compare feature distribution histograms between training and serving data
Common causes of skew: timezone handling, null handling, aggregation window differences
```

---

## NLP Feature Pipelines

### Text Classification Pipeline
```
PRODUCTION PATTERN (2025 best practice):
1. Label with LLM: Use GPT-4/Claude to label 1-5K examples (500-5000x cheaper than manual)
2. Validate labels: Human-review 100-200 samples, measure LLM labeling accuracy
3. IF LLM accuracy > 90% on review → proceed
4. Embed text: sentence-transformers → 384-dim vectors
5. Train classifier: logistic regression or XGBoost on embeddings
6. Evaluate: test set with human labels
7. Deploy: lightweight model (ms latency, pennies per prediction)
Result: LLM-quality at traditional model cost and latency
```

### Topic Modeling
```
Default → BERTopic:
  1. Embed documents with sentence-transformers
  2. Reduce dimensionality with UMAP (n_neighbors=15, n_components=5, min_dist=0.0)
  3. Cluster with HDBSCAN (min_cluster_size=15)
  4. Extract topic words with c-TF-IDF
  5. OPTIONAL: LLM-powered topic labeling (pass top words + sample docs to LLM)

IF need multi-topic per document → LDA (gensim) with coherence-based k selection
IF need hierarchical topics → BERTopic with .hierarchical_topics()
```

### Embedding Best Practices
```
Similarity search → use cosine similarity (normalize embeddings to unit vectors)
Hybrid search → combine dense embeddings + BM25 sparse retrieval (18-42% precision boost)
Cross-encoder reranking → retrieve top-100 with bi-encoder, rerank top-20 with cross-encoder
Dimensionality reduction → IF storage/speed matters, PCA to 128-256 dims (minimal quality loss)
Batch processing → encode in batches of 32-64, use GPU if available
```

### Sentiment Analysis
```
IF need simple polarity → LLM zero-shot with structured output (positive/negative/neutral + score)
IF need aspect-level sentiment → LLM with aspect extraction prompt
IF need high throughput + low cost → distill LLM labels into lightweight classifier (see pipeline above)
IF need multilingual → BGE-M3 embeddings + classifier
VADER and TextBlob are deprecated for new projects — LLM-based approaches are more accurate and easier.
```

---

## LLMs as Feature Extractors

### When to Use LLMs for Feature Engineering
```
IF text contains structured info (addresses, product specs, dates) → LLM extraction to structured fields
IF text quality/topic varies → LLM classification as categorical feature
IF need semantic similarity without labeled data → embedding similarity features
IF need domain-specific scoring (readability, toxicity, relevance) → LLM scoring with rubric
```

### Cost Management
```
For labeling: use strongest model (GPT-4/Claude) on small set, validate, then distill
For feature extraction: use cheapest sufficient model (GPT-4o-mini, Haiku)
For embeddings: use local models (sentence-transformers) — free after initial compute
Cache aggressively: same input → same output, never re-compute
```
