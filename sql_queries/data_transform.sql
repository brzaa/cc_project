CREATE OR REPLACE TABLE `mlops-thesis.mandiri.raw_data` AS (

WITH
transactions_base AS (
    SELECT
        id AS transaction_id,
        COALESCE(date, TIMESTAMP('1900-01-01')) AS transaction_ts,
        COALESCE(client_id, 0) AS client_id,
        COALESCE(card_id, 0) AS card_id,
        COALESCE(SAFE_CAST(amount AS FLOAT64), 0) AS amount,
        COALESCE(TRIM(UPPER(use_chip)), 'UNKNOWN') AS use_chip,
        COALESCE(merchant_id, 0) AS merchant_id,
        COALESCE(TRIM(merchant_city), 'UNKNOWN') AS merchant_city,
        COALESCE(TRIM(merchant_state), 'UNKNOWN') AS merchant_state,
        COALESCE(SAFE_CAST(zip AS INT64), 0) AS zip,
        COALESCE(SAFE_CAST(mcc AS INT64), 0) AS mcc,
        COALESCE(TRIM(errors), 'ERRORLESS') AS errors
    FROM `mlops-thesis.mandiri.transactions`
    WHERE 
        id IS NOT NULL 
        AND date IS NOT NULL
        AND client_id IS NOT NULL
),

cards_base AS (
    SELECT
        id AS card_id,
        COALESCE(client_id, 0) AS client_id,
        COALESCE(TRIM(UPPER(card_brand)), 'UNKNOWN') AS card_brand,
        COALESCE(TRIM(UPPER(card_type)), 'UNKNOWN') AS card_type,
        COALESCE(SAFE_CAST(credit_limit AS FLOAT64), 0) AS credit_limit,
        SAFE.PARSE_DATE('%m/%Y', COALESCE(TRIM(expires), '')) AS expires_date,
        SAFE.PARSE_DATE('%m/%Y', COALESCE(TRIM(acct_open_date), '')) AS acct_open_date
    FROM `mlops-thesis.mandiri.cards`
    WHERE 
        id IS NOT NULL
        AND client_id IS NOT NULL
),

users_base AS (
    SELECT
        id AS client_id,
        COALESCE(SAFE_CAST(yearly_income AS FLOAT64), 0) AS yearly_income,
        COALESCE(SAFE_CAST(credit_score AS INT64), 0) AS credit_score
    FROM `mlops-thesis.mandiri.users`
    WHERE 
        id IS NOT NULL
),

imputation_values AS (
    SELECT
        APPROX_TOP_COUNT(merchant_state, 1)[SAFE_OFFSET(0)].value AS most_common_state,
        ROUND(AVG(CASE WHEN zip > 0 THEN zip END)) AS avg_zip_code
    FROM transactions_base
    WHERE 
        merchant_state != 'UNKNOWN'
        OR zip > 0
),

merged_data AS (
    SELECT
        t.*,
        c.card_brand,
        c.card_type,
        c.credit_limit,
        c.expires_date,
        c.acct_open_date,
        u.yearly_income,
        u.credit_score,
        i.most_common_state,
        i.avg_zip_code
    FROM transactions_base t
    LEFT JOIN cards_base c ON t.card_id = c.card_id
    LEFT JOIN users_base u ON t.client_id = u.client_id
    CROSS JOIN imputation_values i
),

imputed_data AS (
    SELECT
        transaction_id,
        transaction_ts,
        client_id,
        card_id,
        amount,
        use_chip,
        merchant_id,
        merchant_city,
        CASE 
            WHEN merchant_state = 'UNKNOWN' OR merchant_state IS NULL 
            THEN COALESCE(most_common_state, 'UNKNOWN')
            ELSE merchant_state
        END AS merchant_state_imputed,
        CASE 
            WHEN zip = 0 OR zip IS NULL 
            THEN COALESCE(CAST(avg_zip_code AS INT64), 0)
            ELSE zip
        END AS zip_imputed,
        mcc,
        CASE 
            WHEN UPPER(errors) LIKE '%PIN%' THEN 'Bad PIN'
            WHEN UPPER(errors) LIKE '%INSUFFICIENT%' THEN 'Insufficient Balance'  
            WHEN UPPER(errors) LIKE '%TECHNICAL%' THEN 'Technical Glitch'
            WHEN errors = 'ERRORLESS' THEN 'Errorless'
            ELSE COALESCE(errors, 'Errorless')
        END AS errors_imputed,
        COALESCE(card_brand, 'UNKNOWN') AS card_brand,
        COALESCE(card_type, 'UNKNOWN') AS card_type,
        COALESCE(credit_limit, 0) AS credit_limit,
        expires_date,
        acct_open_date,
        COALESCE(yearly_income, 0) AS yearly_income,
        COALESCE(credit_score, 0) AS credit_score,
        most_common_state,
        avg_zip_code
    FROM merged_data
),

enhanced_data AS (
    SELECT
        * EXCEPT (most_common_state, avg_zip_code),
        CASE
            WHEN amount < 0 THEN 'Debit'
            ELSE 'Credit'
        END AS payment_type,
        ABS(amount) AS absolute_amount,
        EXTRACT(DAY FROM transaction_ts) AS transaction_day,
        EXTRACT(MONTH FROM transaction_ts) AS transaction_month,
        EXTRACT(YEAR FROM transaction_ts) AS transaction_year,
        EXTRACT(DAYOFWEEK FROM transaction_ts) AS day_of_week,
        EXTRACT(HOUR FROM transaction_ts) AS transaction_hour,
        CASE 
            WHEN mcc = 5411 THEN 'Grocery'
            WHEN mcc IN (5812, 5813, 5814) THEN 'Restaurant'
            WHEN mcc = 5541 THEN 'Gas Station'
            WHEN mcc = 4121 THEN 'Transportation'
            WHEN mcc = 7011 THEN 'Hotel'
            WHEN mcc BETWEEN 4000 AND 4999 THEN 'Travel'
            WHEN mcc BETWEEN 5000 AND 5099 THEN 'Automotive'
            WHEN mcc BETWEEN 5200 AND 5299 THEN 'Home & Garden'
            WHEN mcc BETWEEN 5300 AND 5399 THEN 'Clothing'
            WHEN mcc BETWEEN 5900 AND 5999 THEN 'General Merchandise'
            WHEN mcc BETWEEN 7200 AND 7299 THEN 'Personal Services'
            WHEN mcc BETWEEN 8000 AND 8999 THEN 'Professional Services'
            ELSE 'Other'
        END AS merchant_category,
        CASE 
            WHEN ABS(amount) >= 15000000 THEN 'Large'
            WHEN ABS(amount) >= 1500000 THEN 'Medium'
            WHEN ABS(amount) >= 150000 THEN 'Small'
            ELSE 'Micro'
        END AS transaction_size_category,
        CASE 
            WHEN EXTRACT(HOUR FROM transaction_ts) BETWEEN 6 AND 11 THEN 'Morning'
            WHEN EXTRACT(HOUR FROM transaction_ts) BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN EXTRACT(HOUR FROM transaction_ts) BETWEEN 18 AND 21 THEN 'Evening'
            ELSE 'Night'
        END AS time_period,
        CASE 
            WHEN EXTRACT(DAYOFWEEK FROM transaction_ts) IN (1, 7) THEN 'Weekend'
            ELSE 'Weekday'
        END AS weekend_indicator
    FROM imputed_data
)

SELECT 
    transaction_id,
    transaction_ts,
    client_id,
    card_id,
    amount,
    absolute_amount,
    payment_type,
    use_chip,
    merchant_id,
    merchant_city,
    merchant_state_imputed,
    zip_imputed,
    mcc,
    merchant_category,
    errors_imputed,
    card_brand,
    card_type,
    credit_limit,
    expires_date,
    acct_open_date,
    yearly_income,
    credit_score,
    transaction_day,
    transaction_month,
    transaction_year,
    day_of_week,
    transaction_hour,
    time_period,
    weekend_indicator,
    transaction_size_category,
    CASE 
        WHEN yearly_income > 0 AND credit_score > 0 AND credit_limit > 0 THEN 'Complete'
        WHEN yearly_income > 0 OR credit_score > 0 OR credit_limit > 0 THEN 'Partial'
        ELSE 'Minimal'
    END AS data_completeness_score
FROM enhanced_data
WHERE 
    client_id > 0
    AND transaction_id IS NOT NULL
    AND transaction_ts >= TIMESTAMP('2000-01-01')
    AND ABS(amount) >= 0
)
