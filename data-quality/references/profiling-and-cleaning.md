# Profiling and Cleaning Reference

Read this file when profiling unknown datasets, cleaning messy or scraped data, deduplicating records, standardizing formats, or handling missing data.

---

## Profiling an Unknown Dataset

### The 10-Minute Profile (run on EVERY new dataset)

Execute in this order. Each step has a decision gate:

```
STEP 1 — Shape: rows, columns, memory footprint
  IF > 1M rows → switch to Polars lazy mode or DuckDB
  IF > 100 columns → likely wide/pivoted, may need to melt

STEP 2 — Types: actual vs apparent types
  IF numeric column stored as string → check for mixed content (e.g., "N/A", "$100")
  IF date column stored as string → catalog all formats before parsing
  IF ID column stored as float → convert to int then string (pandas reads int-with-nulls as float)

STEP 3 — Nulls: null count and rate per column
  IF column >90% null → candidate for dropping (check if structural first)
  IF critical column has ANY nulls → investigate immediately
  IF null rate changed vs historical → flag as potential upstream issue

STEP 4 — Cardinality: unique values per column
  IF cardinality = 1 → zero variance, drop (unless sentinel)
  IF cardinality = row count → candidate primary key
  IF categorical with >100 values → may need grouping/bucketing
  IF ID column cardinality < row count → duplicates exist

STEP 5 — Distributions: min, max, mean, median, std for numerics; top values for categoricals
  IF min/max outside plausible range → data quality error
  IF mean ≫ median → heavy right skew, outliers likely
  IF top category >99% frequency → near-zero variance

STEP 6 — Duplicates: exact row duplicates and key-based duplicates
  IF exact duplicate rate > 0 → deduplicate
  IF key-based duplicate rate > 0 → investigate (which version is correct?)

STEP 7 — Relationships: foreign keys match? Cross-column logic holds?
  IF end_date < start_date → data error
  IF child records reference non-existent parents → referential integrity break
```

### Automated Profiling Tools

```
QUICK (inline, no HTML report):
  df.describe(include='all')           # pandas/Polars basic stats
  duckdb.sql("SUMMARIZE table")        # DuckDB instant profile
  
DETAILED (generates HTML report):
  ydata-profiling: ProfileReport(df, minimal=True for >100K rows)
    → comprehensive: types, nulls, distributions, correlations, alerts
    → use minimal=True to skip expensive computations on large data
  
  Sweetviz: sv.analyze(df) or sv.compare(df_train, df_test)
    → best for: target analysis and dataset comparison
    → faster than ydata-profiling on large datasets

RECOMMENDATION: Use df.describe() + custom checks for routine work.
  Reserve ydata-profiling for first-time encounters with unfamiliar datasets.
```

---

## Cleaning Messy Data

### Encoding and Unicode

```
STEP 1 — Detect encoding:
  IF source encoding known → use it explicitly: pd.read_csv(encoding='utf-8')
  IF unknown → try utf-8 first, fall back to charset-normalizer for detection
  NEVER use chardet (slow, less accurate than charset-normalizer)

STEP 2 — Fix mojibake (garbled characters from double-encoding):
  import ftfy
  clean_text = ftfy.fix_text(garbled_text)
  ftfy handles: UTF-8 decoded as Latin-1, HTML entities, curly quotes, etc.

STEP 3 — Normalize Unicode:
  import unicodedata
  text = unicodedata.normalize('NFKC', text)  # canonical decomposition + compatibility
  NFKC is the default choice — collapses ligatures, normalizes width variants
```

### Whitespace and Invisible Characters

```python
import re

def clean_whitespace(text: str) -> str:
    """Remove phantom whitespace that causes silent matching failures."""
    if not isinstance(text, str):
        return text
    # Remove zero-width characters
    text = re.sub(r'[\u200b\u200c\u200d\u2060\ufeff]', '', text)
    # Convert all whitespace variants to standard space
    text = re.sub(r'[\u00a0\u2000-\u200a\u202f\u205f\u3000]', ' ', text)
    # Collapse multiple spaces and strip
    return re.sub(r' +', ' ', text).strip()

# Apply to all string columns:
# df[str_cols] = df[str_cols].apply(lambda col: col.map(clean_whitespace))
```

### Null Standardization

```python
NULL_VARIANTS = [
    '', 'N/A', 'n/a', 'NA', 'na', 'NULL', 'null', 'None', 'none',
    'NaN', 'nan', '-', '--', '.', '?', 'missing', 'MISSING',
    'not available', 'NOT AVAILABLE', '#N/A', '#NA', 'undefined',
]
# On read: pd.read_csv(path, na_values=NULL_VARIANTS)
# Post-hoc: df.replace(NULL_VARIANTS, pd.NA).replace(r'^\s*$', pd.NA, regex=True)
```

### HTML and Scraping Artifacts

```
STEP 1 — Unescape HTML entities:
  import html
  text = html.unescape(text)  # &amp; → &, &lt; → <, etc.

STEP 2 — Strip HTML tags:
  from bs4 import BeautifulSoup
  text = BeautifulSoup(text, 'html.parser').get_text(separator=' ')

STEP 3 — Remove CSS/JS residue:
  text = re.sub(r'<style[^>]*>.*?</style>', '', text, flags=re.DOTALL)
  text = re.sub(r'<script[^>]*>.*?</script>', '', text, flags=re.DOTALL)

STEP 4 — Remove boilerplate (navigation, footers):
  IF consistent across pages → detect via n-gram frequency (appears in >80% of pages)
  IF inconsistent → use readability heuristics (text-to-tag ratio, paragraph length)

ORDER: Always run steps 1–3 before any text analysis. Step 4 only for NLP pipelines.
```

---

## Deduplication

### Exact Deduplication

```
Python: df.drop_duplicates(subset=key_columns, keep='first')
  IF keep='first' → document which ordering determines "first"
  IF no natural ordering → sort by freshest timestamp

SQL:
  WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (
      PARTITION BY key_col1, key_col2
      ORDER BY updated_at DESC  -- keep most recent
    ) AS rn
    FROM table
  )
  SELECT * FROM ranked WHERE rn = 1;

Hash-based (for large datasets):
  df['_row_hash'] = df.apply(lambda r: hashlib.md5(str(r.values).encode()).hexdigest(), axis=1)
  df.drop_duplicates(subset='_row_hash')
```

### Fuzzy Deduplication

```
STEP 1 — Choose similarity metric:
  Typos in short strings → Levenshtein distance (rapidfuzz.fuzz.ratio)
  Person/company names → Jaro-Winkler (rewards common prefixes)
  Word order varies → token_sort_ratio ("John Smith" ↔ "Smith, John")
  Extra words present → token_set_ratio ("ABC Corp" ↔ "ABC Corporation Inc")

STEP 2 — Set threshold:
  > 95 → very high confidence match
  85–95 → likely match, may need review
  < 85 → likely different, increase with domain knowledge

STEP 3 — Scale with blocking:
  IF < 10K records → brute force all pairs OK
  IF 10K–1M records → block by shared attribute (first 3 chars, zip code, category)
    Only compare within blocks. Reduces O(n²) to O(n·b).
  IF > 1M records → use Splink (Fellegi-Sunter probabilistic model):
    Supports DuckDB, Spark, Athena backends
    ~1M records/minute on laptop via DuckDB
    Outputs match probability per pair, configurable threshold

LIBRARY: Use rapidfuzz (not thefuzz/FuzzyWuzzy). MIT license, ~40% faster, drop-in API.
```

---

## Standardization

### Dates

```
RULE: Parse to datetime immediately, store as ISO 8601, display in local format.

  from dateutil.parser import parse as parse_date
  df['date'] = df['date_str'].apply(lambda x: parse_date(x, dayfirst=False))

  IF ambiguous dates (05/10/2024 — May 10 or Oct 5?):
    → Determine source locale FIRST. Set dayfirst=True for European sources.
    → IF mixed formats in same column → parse row-by-row with format detection
    → IF still ambiguous → flag for manual review, do NOT guess

  IF timezone-naive → make explicit: assume UTC unless source documents otherwise
```

### Phone Numbers, Addresses, Currencies

```
Phone numbers → phonenumbers library:
  import phonenumbers
  parsed = phonenumbers.parse(raw_number, "US")  # specify default country
  standard = phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)

Addresses → usaddress (US) or libpostal/pypostal (international):
  usaddress.tag("123 Main St Apt 4 New York NY 10001")
  → {'AddressNumber': '123', 'StreetName': 'Main', ...}
  libpostal: 98.9% accuracy, 60+ languages, requires ~2GB data download

Currencies → store as integer cents (avoid float arithmetic):
  amount_cents = int(round(float(raw_amount) * 100))
  display: f"${amount_cents / 100:,.2f}"
```

---

## Missing Data Handling

### Step 1: Characterize the Mechanism

```
MCAR (Missing Completely At Random):
  Test: Little's MCAR test, or compare distributions of other variables
    between rows where column IS NULL vs IS NOT NULL.
  IF no significant differences → MCAR likely

MAR (Missing At Random):
  Missingness correlates with other OBSERVED variables.
  Example: income missing more often for younger respondents.
  Detectable by logistic regression: predict is_missing from other columns.

MNAR (Missing Not At Random):
  Missingness depends on the UNOBSERVED value itself.
  Example: high earners skip income question.
  Cannot confirm from data alone — requires domain knowledge.
```

### Step 2: Choose Handling Strategy

```
IF missing rate < 5% AND MCAR → listwise deletion (drop rows)
  Safe, simple, minimal bias.

IF missing rate 5–15% AND MAR → imputation:
  Numeric: KNNImputer(n_neighbors=5) from scikit-learn
  Categorical: mode imputation or KNN with appropriate metric
  ALWAYS create binary _is_missing flag column alongside imputed values.

IF missing rate 15–40% AND MAR → advanced imputation:
  IterativeImputer (MICE) from scikit-learn (experimental, set max_iter=10)
  Estimator: BayesianRidge (default) for numeric, RandomForest for mixed
  Multiple imputation: run 5 times, pool results for uncertainty quantification.

IF missing rate > 40% → consider dropping column:
  BUT first check: is missingness itself informative?
  IF yes → keep as binary flag + optional imputation
  IF no → drop column, document reason

IF structural missing (value doesn't apply to this row):
  Fill with explicit sentinel: "Not Applicable" / 0 / False as appropriate
  Do NOT impute — these aren't missing, they're correctly absent.

NEVER:
  - Impute and forget (always keep _is_missing flag)
  - Use mean imputation on MAR data (introduces bias)
  - Impute the target variable
  - Impute >50% of a column and treat it as reliable
```
