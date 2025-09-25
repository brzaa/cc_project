WITH cleaned_transactions AS (
    SELECT 
        client_id,
        card_id,
        COALESCE(SAFE_CAST(yearly_income AS FLOAT64) * 15000, 0) as annual_income_idr,
        COALESCE(SAFE_CAST(credit_score AS INT64), 0) as credit_score,
        COALESCE(SAFE_CAST(credit_limit AS FLOAT64) * 15000, 0) as credit_limit_idr,
        COALESCE(SAFE_CAST(absolute_amount AS FLOAT64) * 15000, 0) as transaction_amount_idr,
        COALESCE(TRIM(UPPER(payment_type)), 'UNKNOWN') as payment_type,
        COALESCE(TRIM(UPPER(use_chip)), 'UNKNOWN') as chip_usage,
        COALESCE(TRIM(UPPER(errors_imputed)), 'ERRORLESS') as error_status,
        COALESCE(mcc, 0) as merchant_category_code,
        COALESCE(TRIM(merchant_city), 'UNKNOWN') as merchant_city,
        COALESCE(TRIM(merchant_state_imputed), 'UNKNOWN') as merchant_state,
        COALESCE(merchant_id, 0) as merchant_id,
        COALESCE(TRIM(card_brand), 'UNKNOWN') as card_brand,
        transaction_ts,
        SAFE_CAST(transaction_ts AS DATE) as transaction_date,
        EXTRACT(HOUR FROM transaction_ts) as transaction_hour,
        EXTRACT(DAYOFWEEK FROM transaction_ts) as day_of_week,
        EXTRACT(MONTH FROM transaction_ts) as transaction_month,
        EXTRACT(YEAR FROM transaction_ts) as transaction_year,
        transaction_day,
        zip_imputed as zip_code
    FROM `mlops-thesis.mandiri.raw_data`
    WHERE 
        client_id IS NOT NULL
        AND transaction_ts IS NOT NULL
        AND SAFE_CAST(absolute_amount AS FLOAT64) > 0
),

customer_demographics AS (
    SELECT 
        client_id,
        MAX(annual_income_idr) as annual_income_idr,
        MAX(credit_score) as credit_score, 
        MAX(credit_limit_idr) as credit_limit_idr,
        COALESCE(APPROX_TOP_COUNT(card_brand, 1)[SAFE_OFFSET(0)].value, 'UNKNOWN') as primary_card_brand,
        CASE 
            WHEN MAX(annual_income_idr) < 100000000 THEN 'LOW_INCOME'
            WHEN MAX(annual_income_idr) < 300000000 THEN 'MIDDLE_INCOME' 
            WHEN MAX(annual_income_idr) < 500000000 THEN 'UPPER_MIDDLE'
            ELSE 'HIGH_INCOME'
        END as income_segment,
        CASE 
            WHEN MAX(credit_score) >= 750 THEN 'EXCELLENT'
            WHEN MAX(credit_score) >= 700 THEN 'GOOD'
            WHEN MAX(credit_score) >= 650 THEN 'FAIR'
            ELSE 'POOR'
        END as credit_tier,
        CASE 
            WHEN MAX(credit_limit_idr) >= 750000000 THEN 'PREMIUM'
            WHEN MAX(credit_limit_idr) >= 300000000 THEN 'HIGH_LIMIT'
            WHEN MAX(credit_limit_idr) >= 150000000 THEN 'STANDARD'
            ELSE 'BASIC'
        END as credit_limit_tier
    FROM cleaned_transactions
    GROUP BY client_id
),

transaction_behaviors AS (
    SELECT 
        client_id,
        COUNT(*) as total_transactions,
        SUM(transaction_amount_idr) as total_spending_idr,
        ROUND(AVG(transaction_amount_idr), 2) as avg_transaction_amount_idr,
        ROUND(STDDEV(transaction_amount_idr), 2) as spending_volatility_idr,
        
        SUM(CASE WHEN payment_type = 'CREDIT' THEN 1 ELSE 0 END) as credit_transactions,
        SUM(CASE WHEN payment_type = 'DEBIT' THEN 1 ELSE 0 END) as debit_transactions,
        
        SUM(CASE WHEN chip_usage LIKE '%CHIP%' THEN 1 ELSE 0 END) as chip_transactions,
        SUM(CASE WHEN chip_usage LIKE '%SWIPE%' THEN 1 ELSE 0 END) as swipe_transactions,
        
        SUM(CASE WHEN transaction_hour BETWEEN 22 AND 23 OR transaction_hour BETWEEN 0 AND 6 
                 THEN 1 ELSE 0 END) as night_transactions,
        SUM(CASE WHEN day_of_week IN (1, 7) THEN 1 ELSE 0 END) as weekend_transactions,
        SUM(CASE WHEN transaction_hour BETWEEN 9 AND 17 THEN 1 ELSE 0 END) as business_hours_transactions,
        
        SUM(CASE WHEN error_status != 'ERRORLESS' THEN 1 ELSE 0 END) as error_transactions,
        SUM(CASE WHEN error_status LIKE '%PIN%' THEN 1 ELSE 0 END) as pin_error_transactions,
        SUM(CASE WHEN error_status LIKE '%INSUFFICIENT%' THEN 1 ELSE 0 END) as insufficient_balance_errors,
        SUM(CASE WHEN error_status LIKE '%TECHNICAL%' THEN 1 ELSE 0 END) as technical_errors,
        
        COUNT(DISTINCT merchant_city) as unique_cities_visited,
        COUNT(DISTINCT merchant_state) as unique_states_visited,
        COUNT(DISTINCT merchant_id) as unique_merchants_used,
        COUNT(DISTINCT merchant_category_code) as unique_merchant_categories,
        COUNT(DISTINCT card_id) as cards_used,
        
        MIN(transaction_amount_idr) as min_transaction_idr,
        MAX(transaction_amount_idr) as max_transaction_idr,
        APPROX_QUANTILES(transaction_amount_idr, 100)[OFFSET(50)] as median_transaction_idr,
        APPROX_QUANTILES(transaction_amount_idr, 100)[OFFSET(75)] as p75_transaction_idr,
        APPROX_QUANTILES(transaction_amount_idr, 100)[OFFSET(95)] as p95_transaction_idr
    FROM cleaned_transactions
    GROUP BY client_id
),

merchant_category_analysis AS (
    SELECT 
        client_id,
        SUM(CASE WHEN merchant_category_code = 5411 THEN transaction_amount_idr ELSE 0 END) as grocery_spending_idr,
        SUM(CASE WHEN merchant_category_code IN (5812, 5813, 5814) THEN transaction_amount_idr ELSE 0 END) as restaurant_spending_idr,
        SUM(CASE WHEN merchant_category_code = 5541 THEN transaction_amount_idr ELSE 0 END) as gas_spending_idr,
        SUM(CASE WHEN merchant_category_code = 4121 THEN transaction_amount_idr ELSE 0 END) as transportation_spending_idr,
        SUM(CASE WHEN merchant_category_code = 7011 THEN transaction_amount_idr ELSE 0 END) as hotel_spending_idr,
        SUM(CASE WHEN merchant_category_code BETWEEN 4000 AND 4999 THEN transaction_amount_idr ELSE 0 END) as travel_spending_idr,
        SUM(CASE WHEN merchant_category_code BETWEEN 5000 AND 5099 THEN transaction_amount_idr ELSE 0 END) as automotive_spending_idr,
        SUM(CASE WHEN merchant_category_code BETWEEN 5200 AND 5299 THEN transaction_amount_idr ELSE 0 END) as home_garden_spending_idr,
        SUM(CASE WHEN merchant_category_code BETWEEN 5300 AND 5399 THEN transaction_amount_idr ELSE 0 END) as clothing_spending_idr,
        SUM(CASE WHEN merchant_category_code BETWEEN 5900 AND 5999 THEN transaction_amount_idr ELSE 0 END) as general_merchandise_spending_idr,
        
        SUM(CASE WHEN merchant_category_code = 5411 THEN 1 ELSE 0 END) as grocery_transactions,
        SUM(CASE WHEN merchant_category_code IN (5812, 5813, 5814) THEN 1 ELSE 0 END) as restaurant_transactions,
        SUM(CASE WHEN merchant_category_code = 5541 THEN 1 ELSE 0 END) as gas_transactions,
        
        COALESCE(APPROX_TOP_COUNT(merchant_category_code, 1)[SAFE_OFFSET(0)].value, 0) as most_frequent_mcc,
        COUNT(DISTINCT merchant_category_code) as category_diversity
    FROM cleaned_transactions
    WHERE merchant_category_code > 0
    GROUP BY client_id
),

temporal_patterns AS (
    SELECT 
        client_id,
        COUNT(DISTINCT transaction_date) as active_days,
        COUNT(DISTINCT DATE_TRUNC(transaction_date, WEEK)) as active_weeks,
        COUNT(DISTINCT DATE_TRUNC(transaction_date, MONTH)) as active_months,
        COUNT(DISTINCT transaction_year) as active_years,
        
        MIN(transaction_date) as first_transaction_date,
        MAX(transaction_date) as last_transaction_date,
        GREATEST(DATE_DIFF(MAX(transaction_date), MIN(transaction_date), DAY) + 1, 1) as customer_tenure_days,
        
        COALESCE(APPROX_TOP_COUNT(transaction_month, 1)[SAFE_OFFSET(0)].value, 0) as peak_spending_month,
        COALESCE(APPROX_TOP_COUNT(day_of_week, 1)[SAFE_OFFSET(0)].value, 0) as preferred_transaction_day,
        COALESCE(APPROX_TOP_COUNT(transaction_hour, 1)[SAFE_OFFSET(0)].value, 0) as preferred_transaction_hour,
        
        AVG(CASE WHEN day_of_week BETWEEN 2 AND 6 THEN transaction_amount_idr END) as avg_weekday_spending,
        AVG(CASE WHEN day_of_week IN (1, 7) THEN transaction_amount_idr END) as avg_weekend_spending
    FROM cleaned_transactions
    GROUP BY client_id
),

risk_assessment AS (
    SELECT 
        client_id,
        
        CASE 
            WHEN total_transactions > 0 THEN 
                ROUND(CAST(error_transactions AS FLOAT64) / total_transactions * 100, 2)
            ELSE 0 
        END as error_rate_percent,
        
        pin_error_transactions,
        insufficient_balance_errors,
        technical_errors,
        
        CASE 
            WHEN max_transaction_idr > 0 AND avg_transaction_amount_idr > 0 THEN
                ROUND(max_transaction_idr / avg_transaction_amount_idr, 2)
            ELSE 0
        END as transaction_size_volatility_ratio,
        
        CASE 
            WHEN spending_volatility_idr IS NOT NULL AND avg_transaction_amount_idr > 0 THEN
                ROUND(spending_volatility_idr / avg_transaction_amount_idr, 2)
            ELSE 0
        END as spending_consistency_score,
        
        unique_cities_visited,
        unique_states_visited,
        unique_merchants_used,
        cards_used,
        
        CASE 
            WHEN total_transactions > 0 THEN 
                ROUND(CAST(night_transactions AS FLOAT64) / total_transactions * 100, 2)
            ELSE 0 
        END as night_activity_percent,
        
        CASE 
            WHEN CAST(error_transactions AS FLOAT64) / NULLIF(total_transactions, 0) > 0.15 THEN 'HIGH_RISK'
            WHEN pin_error_transactions >= 5 THEN 'SECURITY_RISK'
            WHEN max_transaction_idr / NULLIF(avg_transaction_amount_idr, 0) > 50 THEN 'UNUSUAL_PATTERN'
            WHEN unique_cities_visited > 20 THEN 'HIGH_MOBILITY'
            WHEN cards_used > 3 THEN 'MULTIPLE_CARDS'
            ELSE 'NORMAL'
        END as risk_category
    FROM transaction_behaviors
),

customer_value_segments AS (
    SELECT 
        tb.client_id,
        tb.total_spending_idr,
        tb.total_transactions,
        tp.customer_tenure_days,
        tp.active_days,
        
        CASE 
            WHEN tb.total_spending_idr >= 1500000000 AND tp.customer_tenure_days >= 365 THEN 'VIP'
            WHEN tb.total_spending_idr >= 750000000 THEN 'HIGH_VALUE'
            WHEN tb.total_spending_idr >= 375000000 THEN 'MEDIUM_VALUE'
            WHEN tb.total_spending_idr >= 150000000 THEN 'REGULAR'
            ELSE 'LOW_VALUE'
        END as value_segment,
        
        CASE 
            WHEN tb.total_transactions >= 500 AND tp.active_days >= 100 THEN 'HIGHLY_ENGAGED'
            WHEN tb.total_transactions >= 100 AND tp.active_days >= 30 THEN 'MODERATELY_ENGAGED'
            WHEN tb.total_transactions >= 20 AND tp.active_days >= 10 THEN 'LIGHTLY_ENGAGED'
            ELSE 'MINIMALLY_ENGAGED'
        END as engagement_level,
        
        CASE 
            WHEN tp.customer_tenure_days > 0 THEN 
                ROUND(CAST(tb.total_transactions AS FLOAT64) / tp.customer_tenure_days, 4)
            ELSE 0 
        END as transactions_per_day,
        
        CASE 
            WHEN tp.customer_tenure_days > 0 THEN 
                ROUND(tb.total_spending_idr / tp.customer_tenure_days, 2)
            ELSE 0 
        END as spending_per_day_idr,
        
        CASE 
            WHEN tp.active_days > 0 THEN 
                ROUND(tb.total_spending_idr / tp.active_days, 2)
            ELSE 0 
        END as spending_per_active_day_idr
    FROM transaction_behaviors tb
    INNER JOIN temporal_patterns tp ON tb.client_id = tp.client_id
)

SELECT 
    cd.client_id,
    
    cd.income_segment,
    cd.credit_tier,
    cd.credit_limit_tier,
    cd.primary_card_brand,
    cd.annual_income_idr,
    cd.credit_score,
    cd.credit_limit_idr,
    
    tb.total_transactions,
    tb.total_spending_idr,
    tb.avg_transaction_amount_idr,
    tb.min_transaction_idr,
    tb.max_transaction_idr,
    tb.median_transaction_idr,
    tb.p95_transaction_idr,
    tb.spending_volatility_idr,
    
    CASE 
        WHEN tb.total_transactions > 0 THEN 
            ROUND(CAST(tb.credit_transactions AS FLOAT64) / tb.total_transactions * 100, 1)
        ELSE 0 
    END as credit_usage_percent,
    
    CASE 
        WHEN tb.total_transactions > 0 THEN 
            ROUND(CAST(tb.debit_transactions AS FLOAT64) / tb.total_transactions * 100, 1)
        ELSE 0 
    END as debit_usage_percent,
    
    CASE 
        WHEN tb.total_transactions > 0 THEN 
            ROUND(CAST(tb.chip_transactions AS FLOAT64) / tb.total_transactions * 100, 1)
        ELSE 0 
    END as chip_adoption_percent,
    
    CASE 
        WHEN tb.total_transactions > 0 THEN 
            ROUND(CAST(tb.night_transactions AS FLOAT64) / tb.total_transactions * 100, 1)
        ELSE 0 
    END as night_activity_percent,
    
    CASE 
        WHEN tb.total_transactions > 0 THEN 
            ROUND(CAST(tb.weekend_transactions AS FLOAT64) / tb.total_transactions * 100, 1)
        ELSE 0 
    END as weekend_activity_percent,
    
    CASE 
        WHEN tb.total_transactions > 0 THEN 
            ROUND(CAST(tb.business_hours_transactions AS FLOAT64) / tb.total_transactions * 100, 1)
        ELSE 0 
    END as business_hours_percent,
    
    tb.unique_cities_visited,
    tb.unique_states_visited,
    tb.unique_merchants_used,
    tb.unique_merchant_categories,
    tb.cards_used,
    
    mca.grocery_spending_idr,
    mca.restaurant_spending_idr,
    mca.gas_spending_idr,
    mca.transportation_spending_idr,
    mca.travel_spending_idr,
    mca.automotive_spending_idr,
    mca.clothing_spending_idr,
    mca.most_frequent_mcc,
    mca.category_diversity,
    
    CASE 
        WHEN tb.total_spending_idr > 0 THEN 
            ROUND(mca.grocery_spending_idr / tb.total_spending_idr * 100, 1)
        ELSE 0 
    END as grocery_spending_percent,
    
    CASE 
        WHEN tb.total_spending_idr > 0 THEN 
            ROUND(mca.restaurant_spending_idr / tb.total_spending_idr * 100, 1)
        ELSE 0 
    END as restaurant_spending_percent,
    
    tp.active_days,
    tp.active_weeks,
    tp.active_months,
    tp.active_years,
    tp.customer_tenure_days,
    tp.first_transaction_date,
    tp.last_transaction_date,
    tp.peak_spending_month,
    tp.preferred_transaction_day,
    tp.preferred_transaction_hour,
    
    cvs.value_segment,
    cvs.engagement_level,
    cvs.transactions_per_day,
    cvs.spending_per_day_idr,
    cvs.spending_per_active_day_idr,
    
    ra.error_rate_percent,
    ra.risk_category,
    ra.transaction_size_volatility_ratio,
    ra.spending_consistency_score,
    ra.night_activity_percent as risk_night_activity_percent,
    
    CASE 
        WHEN tp.customer_tenure_days > 0 THEN 
            ROUND(tb.total_spending_idr / tp.customer_tenure_days * 365, 0)
        ELSE 0 
    END as estimated_annual_value_idr,
    
    CASE 
        WHEN tp.customer_tenure_days >= 1095 AND cvs.engagement_level IN ('HIGHLY_ENGAGED', 'MODERATELY_ENGAGED') THEN 'LOYAL'
        WHEN tp.customer_tenure_days >= 730 THEN 'ESTABLISHED'
        WHEN tp.customer_tenure_days >= 365 THEN 'DEVELOPING'
        WHEN tp.customer_tenure_days >= 90 THEN 'RECENT'
        ELSE 'NEW'
    END as loyalty_segment,
    
    CASE 
        WHEN cvs.transactions_per_day >= 0.1 AND ra.error_rate_percent <= 5 THEN 'HIGH_PROFIT_POTENTIAL'
        WHEN cvs.transactions_per_day >= 0.05 AND ra.error_rate_percent <= 15 THEN 'MEDIUM_PROFIT_POTENTIAL'
        ELSE 'LOW_PROFIT_POTENTIAL'
    END as profitability_segment,
    
    CASE 
        WHEN cd.credit_tier = 'EXCELLENT' AND cvs.value_segment IN ('VIP', 'HIGH_VALUE') 
             AND ra.risk_category = 'NORMAL' THEN 'PREMIUM'
        WHEN cd.credit_tier IN ('EXCELLENT', 'GOOD') AND cvs.value_segment IN ('HIGH_VALUE', 'MEDIUM_VALUE') THEN 'PREFERRED'
        WHEN cvs.value_segment = 'REGULAR' AND ra.risk_category = 'NORMAL' THEN 'STANDARD'
        ELSE 'BASIC'
    END as overall_customer_tier

FROM customer_demographics cd
INNER JOIN transaction_behaviors tb ON cd.client_id = tb.client_id
INNER JOIN merchant_category_analysis mca ON cd.client_id = mca.client_id
INNER JOIN temporal_patterns tp ON cd.client_id = tp.client_id
INNER JOIN risk_assessment ra ON cd.client_id = ra.client_id
INNER JOIN customer_value_segments cvs ON cd.client_id = cvs.client_id

WHERE 
    tb.total_transactions >= 1
    AND tp.customer_tenure_days >= 1
    
ORDER BY 
    cvs.value_segment DESC,
    tb.total_spending_idr DESC,
    ra.risk_category,
    cd.client_id;
