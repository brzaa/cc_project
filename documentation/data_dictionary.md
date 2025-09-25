# Data Dictionary - Mandiri Sekuritas User Behavioral Analysis

## Overview
This document defines all fields, business rules, and transformations used in the customer behavioral analysis.

## Source Tables

### 1. `transactions` (Raw)
| Field | Type | Description | Business Rules |
|-------|------|-------------|----------------|
| id | STRING | Transaction unique identifier | Primary key, not null |
| date | TIMESTAMP | Transaction timestamp | Not null, >= 2000-01-01 |
| client_id | INTEGER | Customer unique identifier | Not null, foreign key |
| card_id | INTEGER | Credit card identifier | Not null, foreign key |
| amount | FLOAT | Transaction amount (USD) | Converted to IDR (*15,000) |
| use_chip | STRING | Chip usage indicator | CHIP/SWIPE/UNKNOWN |
| merchant_id | INTEGER | Merchant identifier | Not null |
| merchant_city | STRING | Merchant location city | Cleaned and standardized |
| merchant_state | STRING | Merchant location state | Imputed if missing |
| zip | INTEGER | Merchant zip code | Imputed if missing |
| mcc | INTEGER | Merchant Category Code | Standard MCC classification |
| errors | STRING | Transaction error details | Categorized for analysis |

### 2. `cards` (Raw)
| Field | Type | Description | Business Rules |
|-------|------|-------------|----------------|
| id | INTEGER | Card unique identifier | Primary key |
| client_id | INTEGER | Card owner identifier | Foreign key to users |
| card_brand | STRING | Card brand (VISA/MC/etc) | Standardized values |
| card_type | STRING | Card type classification | CREDIT/DEBIT |
| credit_limit | FLOAT | Credit limit (USD) | Converted to IDR (*15,000) |
| expires | STRING | Card expiration (MM/YYYY) | Parsed to DATE |
| acct_open_date | STRING | Account opening date | Parsed to DATE |

### 3. `users` (Raw)
| Field | Type | Description | Business Rules |
|-------|------|-------------|----------------|
| id | INTEGER | User unique identifier | Primary key |
| yearly_income | FLOAT | Annual income (USD) | Converted to IDR (*15,000) |
| credit_score | INTEGER | Credit score (300-850) | Standard FICO range |

## Transformed Tables

### 1. `raw_data` (Cleaned & Enhanced)

#### Core Transaction Fields
| Field | Type | Description | Derivation |
|-------|------|-------------|------------|
| transaction_id | STRING | Unique transaction ID | From source id |
| transaction_ts | TIMESTAMP | Clean transaction timestamp | Validated and cleaned |
| client_id | INTEGER | Customer ID | Validated not null |
| card_id | INTEGER | Card ID | Validated not null |
| amount | FLOAT | Original amount (USD) | From source |
| absolute_amount | FLOAT | Absolute transaction amount | ABS(amount) |
| payment_type | STRING | CREDIT/DEBIT indicator | IF amount < 0 THEN 'DEBIT' ELSE 'CREDIT' |

#### Enhanced Features
| Field | Type | Description | Business Logic |
|-------|------|-------------|----------------|
| merchant_category | STRING | Human-readable category | MCC mapping to categories |
| transaction_size_category | STRING | Size classification | MICRO(<150K), SMALL(<1.5M), MEDIUM(<15M), LARGE(15M+) |
| time_period | STRING | Time of day classification | Morning(6-11), Afternoon(12-17), Evening(18-21), Night(22-5) |
| weekend_indicator | STRING | Weekend/Weekday flag | Weekend: Saturday(7), Sunday(1) |

#### Risk & Security Fields
| Field | Type | Description | Business Rules |
|-------|------|-------------|----------------|
| errors_imputed | STRING | Categorized error types | PIN errors, Insufficient Balance, Technical, Errorless |
| use_chip | STRING | Chip usage standardized | CHIP/SWIPE/UNKNOWN |
| data_completeness_score | STRING | Data quality indicator | Complete/Partial/Minimal |

### 2. Customer Behavioral Analysis (Final Output)

#### Customer Demographics
| Field | Type | Description | Segmentation Logic |
|-------|------|-------------|-------------------|
| income_segment | STRING | Income classification | LOW(<100M), MIDDLE(100M-300M), UPPER_MIDDLE(300M-500M), HIGH(500M+) |
| credit_tier | STRING | Credit score classification | EXCELLENT(750+), GOOD(700-749), FAIR(650-699), POOR(<650) |
| credit_limit_tier | STRING | Credit limit classification | PREMIUM(750M+), HIGH(300M+), STANDARD(150M+), BASIC(<150M) |
| overall_customer_tier | STRING | Final customer classification | PREMIUM, PREFERRED, STANDARD, BASIC |

#### Transaction Behaviors
| Field | Type | Description | Business Calculation |
|-------|------|-------------|---------------------|
| total_transactions | INTEGER | Total transaction count | COUNT(*) per customer |
| total_spending_idr | FLOAT | Total spending amount | SUM(amount) in IDR |
| avg_transaction_amount_idr | FLOAT | Average transaction size | AVG(amount) in IDR |
| spending_volatility_idr | FLOAT | Spending consistency | STDDEV(amount) in IDR |
| credit_usage_percent | FLOAT | Credit vs total usage | (credit_transactions / total) * 100 |
| chip_adoption_percent | FLOAT | Chip usage rate | (chip_transactions / total) * 100 |

#### Risk Assessment
| Field | Type | Description | Risk Logic |
|-------|------|-------------|------------|
| error_rate_percent | FLOAT | Error transaction rate | (error_transactions / total) * 100 |
| risk_category | STRING | Risk classification | HIGH_RISK(>15% errors), SECURITY_RISK(5+ PIN errors), UNUSUAL_PATTERN, NORMAL |
| night_activity_percent | FLOAT | Off-hours activity | (night_transactions / total) * 100 |
| unique_cities_visited | INTEGER | Geographic mobility | COUNT(DISTINCT merchant_city) |

#### Value Segmentation
| Field | Type | Description | Segment Logic |
|-------|------|-------------|---------------|
| value_segment | STRING | Customer value tier | VIP(1.5B+ & 1yr+), HIGH_VALUE(750M+), MEDIUM_VALUE(375M+), REGULAR(150M+), LOW_VALUE |
| engagement_level | STRING | Activity classification | HIGHLY_ENGAGED(500+ trans, 100+ days), MODERATELY_ENGAGED, LIGHTLY_ENGAGED, MINIMALLY_ENGAGED |
| loyalty_segment | STRING | Tenure classification | LOYAL(3+ yrs & engaged), ESTABLISHED(2+ yrs), DEVELOPING(1+ yr), RECENT(90+ days), NEW |

## Business Rules & Data Quality

### Data Cleaning Rules
1. **Missing Value Imputation:**
   - Merchant state: Use most common state from valid records
   - ZIP code: Use average ZIP from valid records
   - Income/Credit: Default to 0 if missing

2. **Data Validation:**
   - Transaction dates must be >= 2000-01-01
   - Customer ID and Transaction ID must not be null
   - Amount must be >= 0 for analysis

3. **Currency Conversion:**
   - All USD amounts converted to IDR using rate: 1 USD = 15,000 IDR
   - Applied consistently across all monetary fields

### Segmentation Logic

#### Customer Tiers (Final Classification)
- **PREMIUM:** Excellent credit + VIP/High value + Normal risk
- **PREFERRED:** Excellent/Good credit + High/Medium value
- **STANDARD:** Regular value + Normal risk
- **BASIC:** All other customers

#### Risk Categories
- **HIGH_RISK:** Error rate > 15%
- **SECURITY_RISK:** 5+ PIN error attempts
- **UNUSUAL_PATTERN:** Max transaction > 50x average
- **NORMAL:** All other customers

### Key Performance Indicators

#### Customer Value Metrics
- **Annual Revenue per Customer:** Estimated based on tenure and spending
- **Wallet Share:** Percentage of customer spending captured
- **Customer Lifetime Value:** Projected revenue over tenure

#### Risk Metrics
- **Security Incident Rate:** Percentage of customers with security issues
- **Chip Adoption Rate:** Technology modernization indicator
- **Error Rate Threshold:** Operational efficiency metric

## Usage Guidelines

### For Business Analysis
1. Use `overall_customer_tier` for strategic customer prioritization
2. Use `risk_category` for security and fraud prevention
3. Use `value_segment` for revenue optimization
4. Use spending categories for merchant partnership decisions

### For Technical Implementation
1. All monetary values are in IDR (Indonesian Rupiah)
2. Percentages are calculated as ratios * 100
3. Date fields use BigQuery DATE/TIMESTAMP formats
4. String fields are standardized to UPPER case

### Data Refresh Requirements
- Raw data should be refreshed daily
- Customer behavioral analysis should be updated weekly
- Risk assessments require real-time monitoring for security flags

---
*This data dictionary serves as the authoritative source for all field definitions and business rules used in the Mandiri Sekuritas customer behavioral analysis.*
