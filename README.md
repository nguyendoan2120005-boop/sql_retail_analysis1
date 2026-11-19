# Retail Sales Analysis — SQL Server

SQL analysis of 2,000 retail transactions (Jan 2022 – Dec 2023): data cleaning, EDA and 18 business questions using T-SQL (CTEs, window functions, `CASE`).

**Tool:** SQL Server / SSMS · **Database:** `sql_project_p1` · **Table:** `retail_sales` · **Data:** 155 customers, 3 categories (Beauty, Clothing, Electronics)

## Files

- `retail_sales_analysis.sql` — setup, cleaning, EDA, Q1–Q18, findings
- `fix_cogs.sql` — fixes a decimal-import issue in `cogs`
- `SQL - Retail Sales Analysis_utf .csv` — raw data

## Data Cleaning

- Loaded 2,000 rows; deleted 3 rows missing `quantity`, `price`, `cogs`, `total_sale` → **1,997 rows**.
- Kept 10 rows with missing `age` (valid sales). No duplicate IDs, no negative values, `total_sale = quantity × price` holds everywhere.
- **Data issue fixed:** the Import Wizard dropped decimal points in `cogs` (`30.75` → `3075`) on 874 rows because of the Vietnamese locale. I restored the values from the CSV (`fix_cogs.sql`) and verified the totals (`SUM(cogs) = 189,762.70`).

## Results

| # | Question | Result |
|---|---|---|
| Q1 | Transactions on 2022-11-05 | 11 |
| Q2 | Clothing, quantity ≥ 4, Nov-2022 | 17 |
| Q3 | Revenue by category | Electronics 313,810 · Clothing 311,070 · Beauty 286,840 |
| Q4 | Avg age of Beauty customers | 40.42 |
| Q5 | Orders with `total_sale` > 1000 | 306 |
| Q7 | Best month by avg sale | Jul-2022, Feb-2023 (by total revenue: Dec both years) |
| Q8 | Top 5 customers | #3 (38,440), #1, #5, #2, #4 |
| Q9 | Unique customers per category | Clothing 149 · Electronics 144 · Beauty 141 |
| Q10 | Orders by shift | Evening 1,275 · Morning 558 · Afternoon 164 |
| Q11 | Profit margin | Beauty 79.7% · Clothing 79.3% · Electronics 78.6% |
| Q12–13 | Monthly trend | Sep–Dec revenue is 2–3× Jan–Aug |
| Q14 | Age group (avg order value) | 18–24: 503 (highest) → 55+: 417 (lowest) |
| Q15 | Weekday revenue | Sunday highest (153,800), Tuesday lowest (103,395) |
| Q16 | Loyalty | 155 customers, ~12.9 orders each, 100% repeat |
| Q17 | Top 3 spenders per category | see script |
| Q18 | Orders sold below cost | 70 (total loss ≈ 1,713) |

Example — best month per year (CTE + `RANK`):

```sql
WITH monthly_sales AS (
    SELECT YEAR(sale_date) AS sale_year, MONTH(sale_date) AS sale_month,
           AVG(total_sale) AS avg_sale
    FROM retail_sales
    GROUP BY YEAR(sale_date), MONTH(sale_date)
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY sale_year ORDER BY avg_sale DESC) AS rnk
    FROM monthly_sales
)
SELECT sale_year, sale_month, avg_sale FROM ranked WHERE rnk = 1;
```

## Key Findings & Recommendations

- Total revenue 911.7K, profit ~722K (~79% margin); the three categories contribute almost equally.
- **Strong seasonality:** Sep–Dec peak (December highest) → prepare stock and campaigns from August.
- **~64% of orders happen after 17:00**, mid-day is quiet → focus staff and promotions on evenings; test afternoon offers.
- Sunday and Monday are strongest → weekend campaigns.
- Ages 18–24 spend the most per order; 45+ buy more often but smaller baskets → bundles/cross-sell.
- Every customer is a repeat buyer; a few (#3, #1, #5) drive most spend → VIP program.
- 70 single-item orders sold below cost → review pricing and costs.

## How to Run

1. Import the CSV into `sql_project_p1` with *Import Flat File* (table `RetailSales`).
2. Run Section 0 of `retail_sales_analysis.sql` (renames table/columns, sets data types and primary key).
3. Run `fix_cogs.sql` once.
4. Run the remaining sections in order.

*Dataset and the first 10 questions are adapted from a public SQL tutorial; the T-SQL migration, Q11–Q18, data-quality fix and insights are my own work.*
