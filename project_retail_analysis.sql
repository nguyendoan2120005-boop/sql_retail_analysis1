/* =====================================================================
   PROJECT : Retail Sales Analysis
   TOOL    : Microsoft SQL Server (T-SQL) / SSMS
   DATASET : retail_sales (~2,000 giao dịch: ngày, giờ, khách hàng,
             giới tính, tuổi, danh mục, số lượng, giá, giá vốn, doanh thu)
   MỤC TIÊU: Làm sạch dữ liệu, khám phá và trả lời các câu hỏi kinh doanh
             (doanh thu, lợi nhuận, hành vi khách hàng, khung giờ bán hàng)
   ===================================================================== */


/* ---------------------------------------------------------------------
   0. TẠO DATABASE & BẢNG
   --------------------------------------------------------------------- */
IF DB_ID('sql_project_p1') IS NULL
    CREATE DATABASE sql_project_p1;
GO

USE sql_project_p1;
GO

DROP TABLE IF EXISTS retail_sales;
GO

CREATE TABLE retail_sales
(
    transaction_id  INT PRIMARY KEY,
    sale_date       DATE,
    sale_time       TIME,
    customer_id     INT,
    gender          VARCHAR(15),
    age             INT,
    category        VARCHAR(30),
    quantity        INT,
    price_per_unit  DECIMAL(10,2),   -- dùng DECIMAL thay FLOAT cho dữ liệu tiền tệ
    cogs            DECIMAL(10,2),
    total_sale      DECIMAL(10,2)
);
GO

/* Dữ liệu được import bằng Import Flat File Wizard vào bảng tạm
   [dbo].[SQL - Retail Sales Analysis_utf ] (tên cột gốc bị sai chính tả:
   transactions_id, quantiy). Ta chuyển sang bảng chuẩn với tên cột đúng. */
INSERT INTO retail_sales
    (transaction_id, sale_date, sale_time, customer_id, gender, age,
     category, quantity, price_per_unit, cogs, total_sale)
SELECT
    transactions_id, sale_date, sale_time, customer_id, gender, age,
    category, quantiy, price_per_unit, cogs, total_sale
FROM [dbo].[SQL - Retail Sales Analysis_utf ];
GO


drop table [dbo].[retail_sales]
drop table [dbo].[SQL - Retail Sales Analysis_utf ]
-- Kiểm tra nhanh
SELECT TOP (10) * FROM [dbo].[RetailSales]
SELECT COUNT(*) AS total_rows FROM [dbo].[RetailSales]
/* ---------------------------------------------------------------------
   1. LÀM SẠCH DỮ LIỆU (DATA CLEANING)
   --------------------------------------------------------------------- */

-------------------------------------------------------------------------
USE sql_project_p1;
GO

SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME LIKE '%retail%'
ORDER BY TABLE_NAME, ORDINAL_POSITION;
USE sql_project_p1;
GO


EXEC sp_rename 'dbo.retail_sales.transactions_id', 'transaction_id', 'COLUMN';
EXEC sp_rename 
    '[dbo].[RetailSales].quantiy', 
    'quantity', 
    'COLUMN';
GO
-- 1.1 Đếm số giá trị NULL trên từng cột
SELECT
    SUM(CASE WHEN sale_date      IS NULL THEN 1 ELSE 0 END) AS null_sale_date,
    SUM(CASE WHEN sale_time      IS NULL THEN 1 ELSE 0 END) AS null_sale_time,
    SUM(CASE WHEN customer_id    IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN gender         IS NULL THEN 1 ELSE 0 END) AS null_gender,
    SUM(CASE WHEN age            IS NULL THEN 1 ELSE 0 END) AS null_age,
    SUM(CASE WHEN category       IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN quantity       IS NULL THEN 1 ELSE 0 END) AS null_quantity,
    SUM(CASE WHEN price_per_unit IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN cogs           IS NULL THEN 1 ELSE 0 END) AS null_cogs,
    SUM(CASE WHEN total_sale     IS NULL THEN 1 ELSE 0 END) AS null_total_sale
FROM [dbo].[RetailSales]

-- 1.2 Xem các dòng bị thiếu dữ liệu quan trọng TRƯỚC khi xóa
SELECT *
FROM [dbo].[RetailSales]
WHERE sale_date      IS NULL
   OR sale_time      IS NULL
   OR customer_id    IS NULL
   OR gender         IS NULL
   OR category       IS NULL
   OR quantity       IS NULL
   OR price_per_unit IS NULL
   OR cogs           IS NULL
   OR total_sale     IS NULL;

-- 1.3 Xóa các dòng thiếu dữ liệu (giữ lại NULL ở cột age vì không ảnh hưởng doanh thu)
DELETE FROM [dbo].[RetailSales]
WHERE sale_date      IS NULL
   OR sale_time      IS NULL
   OR customer_id    IS NULL
   OR gender         IS NULL
   OR category       IS NULL
   OR quantity       IS NULL
   OR price_per_unit IS NULL
   OR cogs           IS NULL
   OR total_sale     IS NULL;

SELECT COUNT(*) AS rows_after_cleaning FROM [dbo].[RetailSales];

-- 1.4 Kiểm tra tính nhất quán: total_sale phải bằng quantity * price_per_unit
SELECT *
FROM [dbo].[RetailSales]
WHERE total_sale <> quantity * price_per_unit
   OR price_per_unit IS NULL
   OR cogs IS NULL
   OR total_sale IS NULL;

SELECT COUNT(*) AS rows_after_cleaning FROM [dbo].[RetailSales];

-- 1.4 Kiểm tra tính nhất quán: total_sale phải bằng quantity * price_per_unit
SELECT *
FROM [dbo].[RetailSales]
WHERE total_sale <> quantity * price_per_unit;

-- 1.5 Kiểm tra giá trị bất thường (âm hoặc bằng 0)
SELECT *
FROM [dbo].[RetailSales]
WHERE quantity <= 0 OR price_per_unit <= 0 OR total_sale <= 0 OR cogs < 0;

-- 1.6 Chuẩn hóa chuỗi (loại bỏ khoảng trắng thừa)
UPDATE [dbo].[RetailSales]
SET category = LTRIM(RTRIM(category)),
    gender   = LTRIM(RTRIM(gender));


/* ---------------------------------------------------------------------
   2. KHÁM PHÁ DỮ LIỆU (DATA EXPLORATION)
   --------------------------------------------------------------------- */

-- 2.1 Tổng số giao dịch
SELECT COUNT(*) AS total_transactions FROM [dbo].[RetailSales];

-- 2.2 Số khách hàng duy nhất
SELECT COUNT(DISTINCT customer_id) AS unique_customers FROM [dbo].[RetailSales];

-- 2.3 Các danh mục sản phẩm
SELECT DISTINCT category FROM [dbo].[RetailSales];

-- 2.4 Khoảng thời gian dữ liệu & các chỉ số tổng quan
SELECT
    MIN(sale_date)              AS first_sale_date,
    MAX(sale_date)              AS last_sale_date,
    SUM(total_sale)             AS total_revenue,
    SUM(total_sale - cogs)      AS total_profit,
    AVG(total_sale)             AS avg_order_value,
    MIN(age)                    AS min_age,
    MAX(age)                    AS max_age
FROM [dbo].[RetailSales];


/* ---------------------------------------------------------------------
   3. PHÂN TÍCH DỮ LIỆU - TRẢ LỜI CÁC CÂU HỎI KINH DOANH
   --------------------------------------------------------------------- */

-- Q1. Lấy toàn bộ giao dịch của ngày 2022-11-05
SELECT *
FROM [dbo].[RetailSales]
WHERE sale_date = '2022-11-05';


-- Q2. Giao dịch danh mục 'Clothing' có số lượng >= 4 trong tháng 11/2022
--     (Lưu ý: số lượng tối đa trong dữ liệu là 5 nên ngưỡng ">10" sẽ không có kết quả)
SELECT *
FROM [dbo].[RetailSales]
WHERE category = 'Clothing'
  AND sale_date >= '2022-11-01'
  AND sale_date <  '2022-12-01'
  AND quantity  >= 4;


-- Q3. Tổng doanh thu và số đơn hàng theo từng danh mục
SELECT
    category,
    SUM(total_sale) AS net_sale,
    COUNT(*)        AS total_orders
FROM [dbo].[RetailSales]
GROUP BY category
ORDER BY net_sale DESC;


-- Q4. Độ tuổi trung bình của khách mua danh mục 'Beauty'
--     (ép kiểu FLOAT, nếu không AVG của cột INT sẽ bị làm tròn xuống số nguyên)
SELECT
    ROUND(AVG(CAST(age AS FLOAT)), 2) AS avg_age
FROM [dbo].[RetailSales]
WHERE category = 'Beauty';


-- Q5. Các giao dịch có total_sale > 1000
SELECT *
FROM [dbo].[RetailSales]
WHERE total_sale > 1000;


-- Q6. Số giao dịch theo giới tính trong từng danh mục
SELECT
    category,
    gender,
    COUNT(*) AS total_trans
FROM [dbo].[RetailSales]
GROUP BY category, gender
ORDER BY category, gender;


-- Q7. Doanh thu trung bình mỗi tháng và tháng bán tốt nhất trong từng năm
WITH monthly_sales AS
(
    SELECT
        YEAR(sale_date)  AS sale_year,
        MONTH(sale_date) AS sale_month,
        AVG(total_sale)  AS avg_sale,
        SUM(total_sale)  AS total_revenue
    FROM [dbo].[RetailSales]
    GROUP BY YEAR(sale_date), MONTH(sale_date)
),
ranked AS
(
    SELECT *,
           RANK() OVER (PARTITION BY sale_year ORDER BY avg_sale DESC) AS rnk
    FROM monthly_sales
)
SELECT sale_year, sale_month, avg_sale, total_revenue
FROM ranked
WHERE rnk = 1
ORDER BY sale_year;


-- Q8. Top 5 khách hàng có tổng chi tiêu cao nhất
SELECT TOP (5)
    customer_id,
    SUM(total_sale) AS total_sales
FROM [dbo].[RetailSales]
GROUP BY customer_id
ORDER BY total_sales DESC;


-- Q9. Số khách hàng duy nhất của từng danh mục
SELECT
    category,
    COUNT(DISTINCT customer_id) AS cnt_unique_customers
FROM [dbo].[RetailSales]
GROUP BY category
ORDER BY cnt_unique_customers DESC;


-- Q10. Số đơn hàng theo ca: Morning (<12h), Afternoon (12-17h), Evening (>17h)
WITH hourly_sale AS
(
    SELECT *,
        CASE
            WHEN DATEPART(HOUR, sale_time) < 12              THEN 'Morning'
            WHEN DATEPART(HOUR, sale_time) BETWEEN 12 AND 17 THEN 'Afternoon'
            ELSE 'Evening'
        END AS shift
    FROM [dbo].[RetailSales]
)
SELECT
    shift,
    COUNT(*) AS total_orders
FROM hourly_sale
GROUP BY shift
ORDER BY total_orders DESC;


/* ---------------------------------------------------------------------
   4. PHÂN TÍCH NÂNG CAO (BỔ SUNG)
   --------------------------------------------------------------------- */

-- Q11. Lợi nhuận và biên lợi nhuận theo danh mục
SELECT
    category,
    SUM(total_sale)                                        AS revenue,
    SUM(cogs)                                              AS total_cogs,
    SUM(total_sale - cogs)                                 AS profit,
    ROUND(SUM(total_sale - cogs) * 100.0 / SUM(total_sale), 2) AS profit_margin_pct
FROM [dbo].[RetailSales]
GROUP BY category
ORDER BY profit DESC;


-- Q12. Tăng trưởng doanh thu theo tháng (Month-over-Month)
WITH monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(sale_date), MONTH(sale_date), 1) AS month_start,
        SUM(total_sale) AS revenue
    FROM [dbo].[RetailSales]
    GROUP BY DATEFROMPARTS(YEAR(sale_date), MONTH(sale_date), 1)
)
SELECT
    month_start,
    revenue,
    LAG(revenue) OVER (ORDER BY month_start) AS prev_month_revenue,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY month_start)) * 100.0
          / NULLIF(LAG(revenue) OVER (ORDER BY month_start), 0), 2) AS mom_growth_pct
FROM monthly
ORDER BY month_start;


-- Q13. Doanh thu lũy kế theo tháng trong từng năm (Running Total)
WITH monthly AS
(
    SELECT
        YEAR(sale_date)  AS sale_year,
        MONTH(sale_date) AS sale_month,
        SUM(total_sale)  AS revenue
    FROM [dbo].[RetailSales]
    GROUP BY YEAR(sale_date), MONTH(sale_date)
)
SELECT
    sale_year,
    sale_month,
    revenue,
    SUM(revenue) OVER (PARTITION BY sale_year ORDER BY sale_month) AS ytd_revenue
FROM monthly
ORDER BY sale_year, sale_month;


-- Q14. Phân khúc khách hàng theo nhóm tuổi
SELECT
    CASE
        WHEN age < 25             THEN '18-24'
        WHEN age BETWEEN 25 AND 34 THEN '25-34'
        WHEN age BETWEEN 35 AND 44 THEN '35-44'
        WHEN age BETWEEN 45 AND 54 THEN '45-54'
        ELSE '55+'
    END AS age_group,
    COUNT(*)        AS total_orders,
    SUM(total_sale) AS revenue,
    AVG(total_sale) AS avg_order_value
FROM [dbo].[RetailSales]
WHERE age IS NOT NULL
GROUP BY
    CASE
        WHEN age < 25             THEN '18-24'
        WHEN age BETWEEN 25 AND 34 THEN '25-34'
        WHEN age BETWEEN 35 AND 44 THEN '35-44'
        WHEN age BETWEEN 45 AND 54 THEN '45-54'
        ELSE '55+'
    END
ORDER BY revenue DESC;


-- Q15. Doanh thu theo thứ trong tuần
SELECT
    DATENAME(WEEKDAY, sale_date) AS weekday_name,
    COUNT(*)                     AS total_orders,
    SUM(total_sale)              AS revenue
FROM [dbo].[RetailSales]
GROUP BY DATENAME(WEEKDAY, sale_date), DATEPART(WEEKDAY, sale_date)
ORDER BY DATEPART(WEEKDAY, sale_date);


-- Q16. Khách hàng quay lại (mua từ 2 lần trở lên) và tỷ lệ quay lại
WITH cust AS
(
    SELECT customer_id, COUNT(*) AS orders
    FROM [dbo].[RetailSales]
    GROUP BY customer_id
)
SELECT
    COUNT(*)                                                       AS total_customers,
    SUM(CASE WHEN orders >= 2 THEN 1 ELSE 0 END)                   AS repeat_customers,
    ROUND(SUM(CASE WHEN orders >= 2 THEN 1 ELSE 0 END) * 100.0
          / COUNT(*), 2)                                           AS repeat_rate_pct
FROM cust;


-- Q17. Top 3 khách hàng chi tiêu nhiều nhất trong từng danh mục
WITH cust_cat AS
(
    SELECT
        category,
        customer_id,
        SUM(total_sale) AS total_spent,
        RANK() OVER (PARTITION BY category ORDER BY SUM(total_sale) DESC) AS rnk
    FROM [dbo].[RetailSales]
    GROUP BY category, customer_id
)
SELECT category, customer_id, total_spent, rnk
FROM cust_cat
WHERE rnk <= 3
ORDER BY category, rnk;


/* ---------------------------------------------------------------------
   5. TÓM TẮT PHÁT HIỆN & ĐỀ XUẤT KINH DOANH
   (dữ liệu: 1.997 giao dịch sau làm sạch, 01/2022 - 12/2023, 155 khách hàng)
   ---------------------------------------------------------------------

   A. QUY MÔ & DANH MỤC
   - Tổng doanh thu 911.720: năm 2022 là 452.825, năm 2023 là 458.895 (+1,3%).
   - 3 danh mục đóng góp khá đều: Electronics 313.810 (684 đơn), Clothing 311.070
     (701 đơn), Beauty 286.840 (612 đơn). Beauty thấp nhất cả doanh thu lẫn số đơn.
   - Lợi nhuận gộp ~721.957 (biên ~79%); biên theo danh mục: Beauty 79,7%,
     Clothing 79,3%, Electronics 78,6% (chênh lệch nhỏ).
   - Có 306 đơn trên 1.000; 70 đơn bán lỗ (giá vốn > giá bán), tổng lỗ ~1.713,
     toàn bộ là đơn chỉ 1 sản phẩm -> cần rà soát giá vốn / chính sách giá.

   B. XU HƯỚNG THEO THỜI GIAN
   - Doanh thu có tính MÙA VỤ rất rõ: từ tháng 9 đến tháng 12 đạt 57.000-72.000/tháng,
     gấp 2-3 lần các tháng 1-8 (khoảng 16.000-36.000/tháng).
   - Tháng 9/2022 tăng vọt +191% và tháng 9/2023 tăng +139% so với tháng trước;
     tháng 1 mỗi năm lại rơi mạnh (T1/2023: -67%).
   - Tháng 12 là tháng doanh thu cao nhất cả hai năm (72.880 năm 2022; 69.145 năm 2023).
   - Về giá trị đơn trung bình, tháng tốt nhất là T7/2022 (541) và T2/2023 (535).

   C. HÀNH VI MUA SẮM
   - Khung giờ: Evening (từ 17h) áp đảo với ~1.275 đơn (64%), Morning 558,
     Afternoon (12-17h) chỉ 164 đơn. (Nếu tính 17h là Afternoon như cách chia cũ
     thì Evening 1.062 / Afternoon 377 - vẫn là ca tối đông nhất.)
   - Theo thứ: Chủ nhật (153.800) và thứ Hai (147.695) cao nhất; thứ Ba thấp nhất
     (103.395). Cuối tuần có nhiều đơn nhất (CN 312, T7 309).
   - Giới tính: nữ chi tiêu nhỉnh hơn (465.400 so với 446.320 của nam); nữ mua Beauty
     nhiều hơn nam rõ rệt (330 so với 282 đơn), các danh mục khác cân bằng.
   - Nhóm tuổi: 18-24 có giá trị đơn trung bình cao nhất (503) dù ít đơn nhất (296);
     45-54 và 55+ mua nhiều đơn hơn nhưng giá trị đơn thấp nhất (432 và 417).
     Tuổi trung bình khách mua Beauty: 40,42.

   D. KHÁCH HÀNG
   - 155 khách hàng, mỗi khách trung bình ~12,9 đơn; 100% đã mua từ 2 lần trở lên
     -> tập khách rất trung thành, nên trọng tâm là tăng giá trị mỗi đơn.
   - Top 5 khách theo chi tiêu: #3 (38.440), #1 (30.750), #5 (30.405), #2 (25.295),
     #4 (23.580). Khách #3 dẫn đầu danh mục Electronics, #5 dẫn đầu Clothing,
     #1 dẫn đầu Beauty.
   - Số khách mỗi danh mục tương đương nhau (141-149) -> khách mua đa danh mục.

   E. ĐỀ XUẤT
   1. Tập trung nhân sự, tồn kho và khuyến mãi vào khung 17h-22h và cuối tuần;
      cân nhắc ưu đãi "giờ vàng" buổi chiều để kéo đơn khung 12h-17h.
   2. Chuẩn bị hàng và chiến dịch từ tháng 8 cho mùa cao điểm tháng 9-12; tạo
      chương trình kích cầu cho tháng 1-8 để giảm tính mùa vụ.
   3. Chăm sóc nhóm khách VIP (#3, #1, #5, #2, #4) bằng ưu đãi riêng; với nhóm
      45+ đẩy combo / mua kèm để tăng giá trị mỗi đơn.
   4. Kiểm tra giá vốn của 70 đơn bán lỗ; đặt giá sàn cho sản phẩm giá thấp.
   5. Tăng quảng bá Beauty tới nam giới và nhóm 18-34 để thu hẹp khoảng cách
      doanh thu với hai danh mục còn lại.
   --------------------------------------------------------------------- */
