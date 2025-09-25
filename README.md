# Mandiri Sekuritas - User Behavioral Analysis
## Technical Test: Data Analyst

### Project Overview
This project analyzes user behavior patterns using Mandiri Sekuritas customer transaction data to provide strategic insights for business decision-making.

### 🔍 Analysis Objectives
- Understand customer transaction behaviors and patterns
- Identify risk factors and security concerns
- Segment customers based on value and engagement
- Provide actionable recommendations for premium customer retention

### 📊 Dataset Information
**Data Sources:**
- `transactions` - Customer transaction records
- `cards` - Credit card information and limits  
- `users` - Customer demographic and financial data

**Key Metrics Analyzed:**
- Transaction volumes and amounts (converted to IDR)
- Payment patterns (credit vs debit usage)
- Security metrics (chip adoption, error rates)
- Geographic mobility and merchant diversity
- Temporal spending patterns
- Risk assessment indicators

### 🛠 Technical Implementation

#### Data Transformation Pipeline
```sql
-- File: data_transform.sql
-- Creates clean, enriched dataset with business rules applied
CREATE OR REPLACE TABLE `mlops-thesis.mandiri.raw_data` AS (
    -- Data cleaning, validation, and feature engineering
    -- Handles missing values and standardizes formats
    -- Creates derived fields for business analysis
)
```

#### Customer Behavioral Analysis
```sql
-- File: user_behavioral_analysis.sql  
-- Comprehensive customer segmentation and risk analysis
-- Generates customer profiles with 70+ behavioral indicators
-- Creates business segments: Premium, Preferred, Standard, Basic
```

### 📈 Key Findings

#### Customer Portfolio Composition
- **71% Premium customers** (873 clients) with 791M IDR average income
- **24% Affluent customers** (294 clients) with 426M IDR average income
- **95% upper segment positioning** - premium portfolio strategy

#### Critical Security Concerns
- **60% of cards flagged** for security issues (2,443 cards)
- **Average 12.8 bad PIN attempts** per flagged card
- **Only 36.8% chip adoption** vs industry standards
- **90% of cards show some risk concern**

#### Spending Patterns
- **43% of spending** on travel and lifestyle categories
- **22.55% Transportation & Travel** (highest category)
- **95.2% credit usage** across all segments
- **44.6% off-hours activity** (nights + weekends)

### 🎯 Strategic Recommendations

#### Phase 1: Security Enhancement (90 days)
1. **Implement advanced fraud detection algorithms**
2. **Mandatory chip migration program** 
3. **Enhanced PIN recovery processes**
4. **Customer security education campaign**

#### Phase 2: Premium Experience (6 months)
1. **Dedicated premium service tier**
2. **Travel & lifestyle merchant partnerships**
3. **Personalized rewards programs**
4. **Priority customer support channels**

#### Phase 3: Digital Modernization (12 months)
1. **Enhanced mobile banking features**
2. **API integration for merchant partnerships**
3. **Digital-first customer acquisition**
4. **Advanced analytics platform**

### 📁 Project Structure
```
├── README.md                    # This file
├── sql_queries/
│   ├── data_transform.sql       # Data cleaning and preparation
│   └── user_behavioral_analysis.sql # Customer segmentation analysis
├── presentation/
│   └── mandiri_customer_analysis.pdf # Executive presentation
├── dashboard/
│   └── looker_dashboard_link.md # Link to Looker Studio dashboard
└── documentation/
    └── data_dictionary.md       # Field definitions and business rules
```

### 🔧 How to Run the Code

#### Prerequisites
- Google BigQuery access with project `mlops-thesis`
- Dataset `mandiri` with tables: `transactions`, `cards`, `users`
- Looker Studio access for dashboard creation

#### Execution Steps
1. **Data Preparation:**
   ```sql
   -- Run data_transform.sql first to create clean dataset
   -- This creates the `mlops-thesis.mandiri.raw_data` table
   ```

2. **Behavioral Analysis:**
   ```sql
   -- Run user_behavioral_analysis.sql to generate customer profiles
   -- Creates comprehensive customer segmentation with risk assessment
   ```

3. **Dashboard Creation:**
   - Import BigQuery results into Looker Studio
   - Connect to `mlops-thesis.mandiri` dataset
   - Use provided dashboard template and customizations

#### Key Tables Created
- `mlops-thesis.mandiri.raw_data` - Clean, enriched transaction data
- Customer behavioral analysis view - Segmented customer profiles with 70+ metrics

### 📊 Business Impact

**Bottom Line:** Mandiri faces a "High Value, High Risk" scenario with 71% premium customers driving significant revenue, but 60% of cards showing security concerns.

**Immediate Action Required:** Prioritize premium customer retention through security enhancement and targeted experience optimization.

**Success Metrics:**
- Reduce security incidents by 80% within 90 days
- Increase chip adoption to 90%+ within 6 months  
- Improve premium customer satisfaction scores by 25%
- Achieve 15% increase in wallet share through merchant partnerships

### 👤 Author
**Bramastya Zaki** - Data Analyst Technical Test  
Date: 25 September 2025

### 📧 Contact
For questions about this analysis or technical implementation, please contact me.

---
*This analysis provides strategic insights for Mandiri Sekuritas customer portfolio optimization based on comprehensive behavioral data analysis.*
