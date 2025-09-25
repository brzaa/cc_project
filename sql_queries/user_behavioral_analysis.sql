WITH customer_profiles AS (
  SELECT 
    client_id,
    MAX(yearly_income * 15000) as annual_income_idr,
    MAX(credit_score) as credit_score,
    MAX(credit_limit * 15000) as credit_limit_idr,
    
    CASE 
      WHEN MAX(yearly_income * 15000) < 100000000 THEN 'LOW_INCOME'
      WHEN MAX(yearly_income * 15000) < 300000000 THEN 'MIDDLE_INCOME'
      WHEN MAX(yearly_income * 15000) < 500000000 THEN 'UPPER_MIDDLE'
      ELSE 'HIGH_INCOME'
    END as income_segment,
    
    CASE 
      WHEN MAX(credit_score) >= 750 THEN 'EXCELLENT'
      WHEN MAX(credit_score) >= 700 THEN 'GOOD' 
      WHEN MAX(credit_score) >= 650 THEN 'FAIR'
      ELSE 'POOR'
    END as credit_tier
    
  FROM `mlops-thesis.mandiri.raw_data`
  GROUP BY client_id
)

SELECT 
  income_segment,
  credit_tier,
  COUNT(*) as customer_count,
  ROUND(AVG(annual_income_idr), 0) as avg_income_idr,
  ROUND(AVG(credit_score), 1) as avg_credit_score,
  ROUND(AVG(credit_limit_idr), 0) as avg_credit_limit_idr,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as customer_percentage
FROM customer_profiles
GROUP BY income_segment, credit_tier
ORDER BY customer_count DESC;

WITH transaction_summary AS (
  SELECT 
    client_id,
    COUNT(*) as total_transactions,
    SUM(absolute_amount * 15000) as total_spending_idr,
    AVG(absolute_amount * 15000) as avg_transaction_amount_idr,
    STDDEV(absolute_amount * 15000) as spending_volatility_idr,
    
    COUNTIF(payment_type = 'Credit') as credit_transactions,
    COUNTIF(payment_type = 'Debit') as debit_transactions,
    COUNTIF(use_chip = 'Chip Transaction') as chip_transactions,
    COUNTIF(use_chip = 'Swipe Transaction') as swipe_transactions,
    
    COUNTIF(EXTRACT(HOUR FROM transaction_ts) BETWEEN 22 AND 23 
             OR EXTRACT(HOUR FROM transaction_ts) BETWEEN 0 AND 6) as night_transactions,
    COUNTIF(EXTRACT(DAYOFWEEK FROM transaction_ts) IN (1, 7)) as weekend_transactions,
    
    COUNT(DISTINCT merchant_city) as unique_cities,
    COUNT(DISTINCT merchant_id) as unique_merchants
    
  FROM `mlops-thesis.mandiri.raw_data`
  GROUP BY client_id
),

spending_segments AS (
  SELECT 
    *,
    CASE 
      WHEN total_spending_idr >= 150000000 THEN 'HIGH_VALUE'
      WHEN total_spending_idr >= 75000000 THEN 'MEDIUM_VALUE'
      WHEN total_spending_idr >= 15000000 THEN 'REGULAR'
      ELSE 'LOW_VALUE'
    END as customer_segment
  FROM transaction_summary
)

SELECT 
  customer_segment,
  COUNT(*) as customer_count,
  ROUND(AVG(total_spending_idr), 0) as avg_spending_idr,
  ROUND(AVG(total_transactions), 1) as avg_transactions,
  ROUND(AVG(SAFE_DIVIDE(credit_transactions, total_transactions)) * 100, 1) as credit_usage_rate_pct,
  ROUND(AVG(SAFE_DIVIDE(chip_transactions, total_transactions)) * 100, 1) as chip_adoption_rate_pct,
  ROUND(AVG(SAFE_DIVIDE(night_transactions, total_transactions)) * 100, 1) as night_activity_rate_pct,
  ROUND(AVG(SAFE_DIVIDE(weekend_transactions, total_transactions)) * 100, 1) as weekend_activity_rate_pct,
  ROUND(AVG(unique_cities), 1) as avg_unique_cities,
  ROUND(AVG(unique_merchants), 1) as avg_unique_merchants
  
FROM spending_segments
GROUP BY customer_segment
ORDER BY avg_spending_idr DESC;

WITH mcc_analysis AS (
  SELECT 
    mcc,
    CASE 
      WHEN mcc = 5411 THEN 'Grocery Stores'
      WHEN mcc IN (5812, 5813, 5814) THEN 'Restaurants'
      WHEN mcc = 5541 THEN 'Gas Stations'
      WHEN mcc = 4121 THEN 'Transportation'
      WHEN mcc = 7011 THEN 'Hotels/Lodging'
      WHEN mcc = 7538 THEN 'Auto Services'
      WHEN mcc BETWEEN 4000 AND 4999 THEN 'Transportation & Travel'
      WHEN mcc BETWEEN 5000 AND 5099 THEN 'Automotive'
      WHEN mcc BETWEEN 5200 AND 5299 THEN 'Home & Garden'
      WHEN mcc BETWEEN 5300 AND 5399 THEN 'Clothing & Accessories'
      WHEN mcc BETWEEN 5900 AND 5999 THEN 'General Merchandise'
      WHEN mcc BETWEEN 7200 AND 7299 THEN 'Personal Services'
      WHEN mcc BETWEEN 8000 AND 8999 THEN 'Professional Services'
      ELSE CONCAT('Other (MCC: ', CAST(mcc AS STRING), ')')
    END as category,
    
    COUNT(*) as transaction_count,
    SUM(absolute_amount * 15000) as total_amount_idr,
    AVG(absolute_amount * 15000) as avg_amount_idr,
    COUNT(DISTINCT client_id) as unique_customers
    
  FROM `mlops-thesis.mandiri.raw_data`
  GROUP BY mcc
),

category_summary AS (
  SELECT 
    category,
    SUM(transaction_count) as total_transactions,
    SUM(total_amount_idr) as total_spending_idr,
    AVG(avg_amount_idr) as avg_transaction_size_idr,
    SUM(unique_customers) as total_customers
  FROM mcc_analysis
  GROUP BY category
)

SELECT 
  category,
  total_transactions,
  ROUND(total_spending_idr, 0) as total_spending_idr,
  ROUND(avg_transaction_size_idr, 0) as avg_transaction_size_idr,
  total_customers,
  ROUND(total_spending_idr / (SELECT SUM(total_spending_idr) FROM category_summary) * 100, 2) as spending_share_pct,
  ROUND(total_transactions / (SELECT SUM(total_transactions) FROM category_summary) * 100, 2) as transaction_share_pct
FROM category_summary
ORDER BY total_spending_idr DESC;

WITH risk_metrics AS (
  SELECT 
    client_id,
    card_id,
    COUNT(*) as total_transactions,
    COUNTIF(errors_imputed != 'Errorless') as error_transactions,
    COUNTIF(errors_imputed = 'Bad PIN') as bad_pin_attempts,
    COUNTIF(errors_imputed = 'Insufficient Balance') as insufficient_balance,
    COUNTIF(errors_imputed = 'Technical Glitch') as technical_errors,
    COUNTIF(amount < 0) as refund_transactions,
    MAX(absolute_amount * 15000) as max_transaction_idr,
    AVG(absolute_amount * 15000) as avg_transaction_idr
  FROM `mlops-thesis.mandiri.raw_data`
  GROUP BY client_id, card_id
),

risk_categorized AS (
  SELECT 
    *,
    CASE 
      WHEN SAFE_DIVIDE(error_transactions, total_transactions) > 0.1 THEN 'HIGH_ERROR_RATE'
      WHEN bad_pin_attempts >= 3 THEN 'SECURITY_CONCERN'  
      WHEN SAFE_DIVIDE(max_transaction_idr, NULLIF(avg_transaction_idr, 0)) > 10 THEN 'UNUSUAL_LARGE_TXN'
      ELSE 'NORMAL'
    END as risk_category
  FROM risk_metrics 
  WHERE total_transactions >= 5
)

SELECT 
  risk_category,
  COUNT(*) as card_count,
  ROUND(AVG(SAFE_DIVIDE(error_transactions, total_transactions)) * 100, 2) as avg_error_rate_pct,
  ROUND(AVG(bad_pin_attempts), 1) as avg_bad_pins,
  ROUND(AVG(insufficient_balance), 1) as avg_insufficient_balance,
  ROUND(AVG(technical_errors), 1) as avg_technical_errors,
  ROUND(AVG(refund_transactions), 1) as avg_refunds,
  ROUND(AVG(max_transaction_idr), 0) as avg_max_transaction_idr,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as card_percentage
  
FROM risk_categorized
GROUP BY risk_category
ORDER BY card_count DESC;

WITH monthly_data AS (
  SELECT 
    EXTRACT(YEAR FROM transaction_ts) as year,
    EXTRACT(MONTH FROM transaction_ts) as month,
    COUNT(*) as transaction_count,
    SUM(absolute_amount * 15000) as total_amount_idr,
    AVG(absolute_amount * 15000) as avg_amount_idr,
    COUNT(DISTINCT client_id) as active_customers,
    COUNT(DISTINCT card_id) as active_cards
  FROM `mlops-thesis.mandiri.raw_data`
  GROUP BY year, month
),

with_growth_metrics AS (
  SELECT 
    *,
    LAG(transaction_count, 1) OVER (ORDER BY year, month) as prev_month_count,
    LAG(total_amount_idr, 1) OVER (ORDER BY year, month) as prev_month_amount,
    LAG(active_customers, 1) OVER (ORDER BY year, month) as prev_month_customers,
    
    ROUND(
      (transaction_count - LAG(transaction_count, 1) OVER (ORDER BY year, month)) / 
      NULLIF(LAG(transaction_count, 1) OVER (ORDER BY year, month), 0) * 100, 
      2
    ) as txn_mom_growth_pct,
    
    ROUND(
      (total_amount_idr - LAG(total_amount_idr, 1) OVER (ORDER BY year, month)) / 
      NULLIF(LAG(total_amount_idr, 1) OVER (ORDER BY year, month), 0) * 100, 
      2
    ) as amount_mom_growth_pct,
    
    ROUND(
      (active_customers - LAG(active_customers, 1) OVER (ORDER BY year, month)) / 
      NULLIF(LAG(active_customers, 1) OVER (ORDER BY year, month), 0) * 100, 
      2
    ) as customer_mom_growth_pct

  FROM monthly_data
)

SELECT 
  year,
  month,
  transaction_count,
  ROUND(total_amount_idr, 0) as total_amount_idr,
  ROUND(avg_amount_idr, 0) as avg_amount_idr,
  active_customers,
  active_cards,
  txn_mom_growth_pct,
  amount_mom_growth_pct,
  customer_mom_growth_pct,
  
  CASE month
    WHEN 1 THEN 'January'
    WHEN 2 THEN 'February' 
    WHEN 3 THEN 'March'
    WHEN 4 THEN 'April'
    WHEN 5 THEN 'May'
    WHEN 6 THEN 'June'
    WHEN 7 THEN 'July'
    WHEN 8 THEN 'August'
    WHEN 9 THEN 'September'
    WHEN 10 THEN 'October'
    WHEN 11 THEN 'November'
    WHEN 12 THEN 'December'
  END as month_name

FROM with_growth_metrics
ORDER BY year, month;

WITH customer_360 AS (
  SELECT 
    rd.client_id,
    
    MAX(rd.yearly_income * 15000) as annual_income_idr,
    MAX(rd.credit_score) as credit_score,
    MAX(rd.credit_limit * 15000) as credit_limit_idr,
    
    COUNT(*) as total_transactions,
    SUM(rd.absolute_amount * 15000) as total_spending_idr,
    AVG(rd.absolute_amount * 15000) as avg_transaction_idr,
    
    AVG(CASE WHEN rd.payment_type = 'Credit' THEN 1.0 ELSE 0.0 END) as credit_preference,
    AVG(CASE WHEN rd.use_chip = 'Chip Transaction' THEN 1.0 ELSE 0.0 END) as chip_preference,
    
    COUNT(DISTINCT rd.merchant_city) as cities_visited,
    COUNT(DISTINCT rd.merchant_id) as merchants_used,
    COUNT(DISTINCT rd.mcc) as category_diversity,
    
    AVG(CASE WHEN EXTRACT(HOUR FROM rd.transaction_ts) BETWEEN 9 AND 17 THEN 1.0 ELSE 0.0 END) as business_hours_activity,
    AVG(CASE WHEN EXTRACT(DAYOFWEEK FROM rd.transaction_ts) IN (2,3,4,5,6) THEN 1.0 ELSE 0.0 END) as weekday_activity,
    
    AVG(CASE WHEN rd.errors_imputed != 'Errorless' THEN 1.0 ELSE 0.0 END) as error_rate
    
  FROM `mlops-thesis.mandiri.raw_data` rd
  GROUP BY rd.client_id
  HAVING COUNT(*) >= 10
),

customer_segments AS (
  SELECT 
    *,
    CASE 
      WHEN annual_income_idr >= 500000000 AND total_spending_idr >= 150000000 THEN 'PREMIUM'
      WHEN annual_income_idr >= 300000000 AND total_spending_idr >= 75000000 THEN 'AFFLUENT'
      WHEN annual_income_idr >= 100000000 AND total_spending_idr >= 30000000 THEN 'MASS_MARKET'
      ELSE 'BASIC'
    END as customer_tier
    
  FROM customer_360
)

SELECT 
  customer_tier,
  COUNT(*) as customer_count,
  
  ROUND(AVG(annual_income_idr), 0) as avg_annual_income_idr,
  ROUND(AVG(credit_score), 0) as avg_credit_score,
  ROUND(AVG(credit_limit_idr), 0) as avg_credit_limit_idr,
  
  ROUND(AVG(total_spending_idr), 0) as avg_total_spending_idr,
  ROUND(AVG(avg_transaction_idr), 0) as avg_transaction_size_idr,
  ROUND(AVG(total_transactions), 0) as avg_transactions,
  
  ROUND(AVG(cities_visited), 1) as avg_cities_visited,
  ROUND(AVG(merchants_used), 0) as avg_merchants_used,
  ROUND(AVG(category_diversity), 0) as avg_categories,
  
  ROUND(AVG(credit_preference) * 100, 1) as credit_usage_pct,
  ROUND(AVG(chip_preference) * 100, 1) as chip_adoption_pct,
  ROUND(AVG(business_hours_activity) * 100, 1) as business_hours_pct,
  ROUND(AVG(weekday_activity) * 100, 1) as weekday_activity_pct,
  ROUND(AVG(error_rate) * 100, 2) as avg_error_rate_pct

FROM customer_segments
GROUP BY customer_tier
ORDER BY avg_total_spending_idr DESC;
