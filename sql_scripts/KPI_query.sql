USE CreditBI_DB;
GO

-- =========================
-- 1. Tổng dư nợ hiện tại
-- Tổng dư nợ hiện tại là tổng số tiền gốc khách hàng còn nợ (out_prncp)
-- =========================

SELECT 
    SUM(out_prncp) AS Tong_Du_No_Hien_Tai 
FROM Fact_Loans;

-- =========================
-- 2. Tỷ lệ hoàn trả khoản vay (Repayment Rate):
-- Là tỷ lệ phần trăm giữa tổng số tiền đã thanh toán (total_pymnt) trên tổng số tiền đã giải ngân (loan_amnt).
-- =========================

SELECT 
    SUM(total_pymnt) AS Tong_Da_Thanh_Toan,
    SUM(loan_amnt) AS Tong_Giai_Ngan,
    ROUND((SUM(total_pymnt) / NULLIF(SUM(loan_amnt), 0)) * 100, 2) AS Ty_Le_Hoan_Tra_Phan_Tram
FROM Fact_Loans;

-- =========================
-- 3. Tỷ lệ nợ xấu trên tổng dư nợ (NPL Ratio)
-- NPL (Non-Performing Loan) được xác định bằng cờ npl_flag = 1 trong bảng Dim_CreditRisk. Truy vấn tính tỷ lệ giá trị các khoản vay nợ xấu trên tổng giá trị các khoản vay.
-- =========================

SELECT 
    SUM(CASE WHEN r.npl_flag = 1 THEN f.loan_amnt ELSE 0 END) AS Tong_No_Xau,
    SUM(f.loan_amnt) AS Tong_Du_No,
    ROUND(
        SUM(CASE WHEN r.npl_flag = 1 THEN f.loan_amnt ELSE 0 END) * 100.0 / NULLIF(SUM(f.loan_amnt), 0), 2
    ) AS NPL_Ratio_Phan_Tram
FROM Fact_Loans f
JOIN Dim_CreditRisk r ON f.risk_id = r.risk_id;

-- =========================
-- 4. Phân bổ khoản vay (Loan Distribution)
-- =========================
-- a) Phân bổ theo Grade (Xếp hạng): Sử dụng bảng Dim_LoanProduct.
-- =========================

SELECT 
    p.grade AS Xep_Hang_Tin_Dung,
    COUNT(f.loan_id) AS So_Khoan_Vay,
    SUM(f.loan_amnt) AS Tong_Giai_Ngan,
    ROUND(COUNT(f.loan_id) * 100.0 / SUM(COUNT(f.loan_id)) OVER(), 2) AS Ty_Trong_So_Luong_Phan_Tram
FROM Fact_Loans f
JOIN Dim_LoanProduct p ON f.product_id = p.product_id
GROUP BY p.grade
ORDER BY p.grade;

-- =========================
-- b) Phân bổ theo Mục đích vay: Sử dụng trường purpose.
-- =========================

SELECT 
    p.purpose AS Muc_Dich_Vay,
    COUNT(f.loan_id) AS So_Khoan_Vay,
    SUM(f.loan_amnt) AS Tong_Giai_Ngan
FROM Fact_Loans f
JOIN Dim_LoanProduct p ON f.product_id = p.product_id
GROUP BY p.purpose
ORDER BY Tong_Giai_Ngan DESC;

-- =========================
-- c) Phân bổ theo Khu vực: Sử dụng bảng Dim_Geography (region hoặc addr_state).
-- =========================

SELECT 
    g.region AS Vung_Mien,
    COUNT(f.loan_id) AS So_Khoan_Vay,
    SUM(f.loan_amnt) AS Tong_Giai_Ngan,
    ROUND(AVG(f.int_rate), 2) AS Lai_Suat_Trung_Binh
FROM Fact_Loans f
JOIN Dim_Geography g ON f.geo_id = g.geo_id
GROUP BY g.region
ORDER BY Tong_Giai_Ngan DESC;

-- =========================
-- 5. Rủi ro theo nhóm tín dụng (Risk by Grade)

-- Kết hợp bảng Dim_LoanProduct và Dim_CreditRisk để xem tỷ lệ nợ xấu (npl_flag = 1) xảy ra ở các nhóm hạng tín dụng nào nhiều nhất.
-- =========================

SELECT 
    p.grade AS Xep_Hang,
    COUNT(f.loan_id) AS Tong_So_Khoan_Vay,
    SUM(CASE WHEN r.npl_flag = 1 THEN 1 ELSE 0 END) AS So_Khoan_No_Xau,
    SUM(f.loan_amnt) AS Tong_Du_No,
    SUM(CASE WHEN r.npl_flag = 1 THEN f.loan_amnt ELSE 0 END) AS Du_No_Xau,
    ROUND(
        SUM(CASE WHEN r.npl_flag = 1 THEN f.loan_amnt ELSE 0 END) * 100.0 / NULLIF(SUM(f.loan_amnt), 0), 2
    ) AS Ty_Le_Rui_Ro_Phan_Tram
FROM Fact_Loans f
JOIN Dim_LoanProduct p ON f.product_id = p.product_id
JOIN Dim_CreditRisk r ON f.risk_id = r.risk_id
GROUP BY p.grade
ORDER BY p.grade;

-- =========================
-- 6. Recovery Analysis: Hiệu quả thu hồi nợ theo thời gian
-- Đánh giá dòng tiền thu hồi (recoveries) của những khoản vay đã bị đánh dấu là nợ xấu hoặc mất khả năng thanh toán theo các năm giải ngân (issue_year).
-- =========================

SELECT 
    t.issue_year AS Nam_Giai_Ngan,
    COUNT(f.loan_id) AS So_Khoan_Vay_Rui_Ro,
    SUM(f.loan_amnt) AS Tong_Gia_Tri_Khoan_Vay,
    SUM(f.recoveries) AS Tong_Da_Thu_Hoi,
    ROUND(
        SUM(f.recoveries) * 100.0 / NULLIF(SUM(f.loan_amnt), 0), 2
    ) AS Hieu_Qua_Thu_Hoi_Phan_Tram
FROM Fact_Loans f
JOIN Dim_Time t ON f.time_id = t.time_id
JOIN Dim_CreditRisk r ON f.risk_id = r.risk_id
WHERE r.npl_flag = 1 OR r.is_recovered = 1 
GROUP BY t.issue_year
ORDER BY t.issue_year;

-- =========================
-- 7. Trend Analysis (Xu hướng giải ngân): Phân tích bằng cách kết hợp với bảng Dim_Time.
-- =========================
-- Theo Tháng và Năm:
-- =========================

SELECT 
    t.issue_year AS Nam,
    t.issue_month AS Thang,
    COUNT(f.loan_id) AS So_Khoan_Vay_Giai_Ngan,
    SUM(f.loan_amnt) AS Tong_Giai_Ngan,
    ROUND(AVG(f.int_rate), 2) AS Lai_Suat_Trung_Binh
FROM Fact_Loans f
JOIN Dim_Time t ON f.time_id = t.time_id
GROUP BY t.issue_year, t.issue_month
ORDER BY t.issue_year, t.issue_month;

-- =========================
-- Theo Quý và Năm:
-- =========================

SELECT 
    t.issue_year AS Nam,
    t.issue_quarter AS Quy,
    COUNT(f.loan_id) AS So_Khoan_Vay_Giai_Ngan,
    SUM(f.loan_amnt) AS Tong_Giai_Ngan
FROM Fact_Loans f
JOIN Dim_Time t ON f.time_id = t.time_id
GROUP BY t.issue_year, t.issue_quarter
ORDER BY t.issue_year, t.issue_quarter;

-- =========================
-- Tổng quan theo Năm:
-- =========================

SELECT 
    t.issue_year AS Nam,
    COUNT(f.loan_id) AS So_Khoan_Vay,
    SUM(f.loan_amnt) AS Tong_Giai_Ngan,
    ROUND(SUM(f.loan_amnt) - LAG(SUM(f.loan_amnt), 1, 0) OVER(ORDER BY t.issue_year), 2) AS Tang_Truong_So_Voi_Nam_Truoc
FROM Fact_Loans f
JOIN Dim_Time t ON f.time_id = t.time_id
GROUP BY t.issue_year
ORDER BY t.issue_year;


-- =========================
-- 8. Lãi suất trung bình theo Grade
-- Grade cao hơn (E,F,G) thường có lãi suất cao hơn vì rủi ro cao hơn
-- =========================

SELECT 
    p.grade                         AS Xep_Hang,
    COUNT(f.loan_id)                AS So_Khoan_Vay,
    ROUND(AVG(f.int_rate), 2)       AS Lai_Suat_TB,
    ROUND(MIN(f.int_rate), 2)       AS Lai_Suat_Min,
    ROUND(MAX(f.int_rate), 2)       AS Lai_Suat_Max
FROM Fact_Loans f
JOIN Dim_LoanProduct p ON f.product_id = p.product_id
GROUP BY p.grade
ORDER BY p.grade;

-- =========================
-- 9. DTI trung bình theo Risk Tier
-- Kiểm tra nhóm nợ xấu có DTI cao hơn nhóm bình thường không
-- =========================

SELECT 
    r.risk_tier                     AS Muc_Rui_Ro,
    COUNT(f.loan_id)                AS So_Khoan_Vay,
    ROUND(AVG(f.dti), 2)           AS DTI_Trung_Binh,
    ROUND(AVG(f.int_rate), 2)      AS Lai_Suat_TB,
    ROUND(AVG(f.loan_amnt), 2)     AS So_Tien_Vay_TB
FROM Fact_Loans f
JOIN Dim_CreditRisk r ON f.risk_id = r.risk_id
GROUP BY r.risk_tier
ORDER BY DTI_Trung_Binh DESC;

-- =========================
-- 10. Phân bổ theo kỳ hạn (36 vs 60 tháng)
-- Kỳ hạn dài (60 tháng) có tỷ lệ nợ xấu cao hơn không?
-- =========================

SELECT 
    f.term                          AS Ky_Han_Thang,
    COUNT(f.loan_id)                AS So_Khoan_Vay,
    SUM(f.loan_amnt)                AS Tong_Giai_Ngan,
    ROUND(AVG(f.int_rate), 2)      AS Lai_Suat_TB,
    SUM(CASE WHEN r.npl_flag = 1 THEN 1 ELSE 0 END) AS So_Khoan_No_Xau,
    ROUND(
        SUM(CASE WHEN r.npl_flag = 1 THEN 1.0 ELSE 0 END) 
        * 100.0 / NULLIF(COUNT(f.loan_id), 0), 2
    )                               AS Ty_Le_No_Xau_Phan_Tram
FROM Fact_Loans f
JOIN Dim_CreditRisk r ON f.risk_id = r.risk_id
GROUP BY f.term
ORDER BY f.term;

-- =========================
-- 11. Top 10 bang có tỷ lệ nợ xấu cao nhất
-- Xác định vùng địa lý rủi ro cao để tập trung kiểm soát
-- =========================

SELECT TOP 10
    g.addr_state                    AS Bang,
    g.state_name                    AS Ten_Bang,
    g.region                        AS Vung_Mien,
    COUNT(f.loan_id)                AS Tong_Khoan_Vay,
    SUM(CASE WHEN r.npl_flag = 1 THEN 1 ELSE 0 END) AS So_Khoan_No_Xau,
    SUM(f.loan_amnt)                AS Tong_Du_No,
    SUM(CASE WHEN r.npl_flag = 1 THEN f.loan_amnt ELSE 0 END) AS Du_No_Xau,
    ROUND(
        SUM(CASE WHEN r.npl_flag = 1 THEN f.loan_amnt ELSE 0 END) * 100.0
        / NULLIF(SUM(f.loan_amnt), 0), 2
    )                               AS NPL_Ratio_Phan_Tram
FROM Fact_Loans f
JOIN Dim_Geography g  ON f.geo_id  = g.geo_id
JOIN Dim_CreditRisk r ON f.risk_id = r.risk_id
GROUP BY g.addr_state, g.state_name, g.region
ORDER BY NPL_Ratio_Phan_Tram DESC;

-- =========================
-- 12. Tỷ lệ thu hồi nợ theo Grade
-- Grade nào thu hồi được nhiều tiền hơn sau khi xảy ra nợ xấu
-- =========================

SELECT 
    p.grade                         AS Xep_Hang,
    COUNT(f.loan_id)                AS So_Khoan_No_Xau,
    ROUND(SUM(f.loan_amnt), 2)     AS Tong_Du_No_Goc,
    ROUND(SUM(f.recoveries), 2)    AS Tong_Thu_Hoi,
    ROUND(
        SUM(f.recoveries) * 100.0 
        / NULLIF(SUM(f.loan_amnt), 0), 2
    )                               AS Ty_Le_Thu_Hoi_Phan_Tram
FROM Fact_Loans f
JOIN Dim_LoanProduct p  ON f.product_id = p.product_id
JOIN Dim_CreditRisk r   ON f.risk_id    = r.risk_id
WHERE r.npl_flag = 1
GROUP BY p.grade
ORDER BY p.grade;

-- =========================
-- 13. Tăng trưởng NPL theo năm
-- Xu hướng nợ xấu tăng hay giảm theo thời gian
-- =========================

SELECT 
    t.issue_year                    AS Nam,
    COUNT(f.loan_id)                AS Tong_Khoan_Vay,
    SUM(CASE WHEN r.npl_flag = 1 THEN 1 ELSE 0 END) AS So_Khoan_No_Xau,
    SUM(f.loan_amnt)                AS Tong_Giai_Ngan,
    SUM(CASE WHEN r.npl_flag = 1 THEN f.loan_amnt ELSE 0 END) AS Du_No_Xau,
    ROUND(
        SUM(CASE WHEN r.npl_flag = 1 THEN f.loan_amnt ELSE 0 END) * 100.0
        / NULLIF(SUM(f.loan_amnt), 0), 2
    )                               AS NPL_Ratio_Theo_Nam,
    ROUND(
        SUM(CASE WHEN r.npl_flag = 1 THEN f.loan_amnt ELSE 0 END)
        - LAG(SUM(CASE WHEN r.npl_flag = 1 THEN f.loan_amnt ELSE 0 END), 1, 0)
          OVER (ORDER BY t.issue_year), 2
    )                               AS Tang_Truong_No_Xau_So_Nam_Truoc
FROM Fact_Loans f
JOIN Dim_Time t       ON f.time_id  = t.time_id
JOIN Dim_CreditRisk r ON f.risk_id  = r.risk_id
GROUP BY t.issue_year
ORDER BY t.issue_year;

-- =========================
-- 14. Điểm FICO trung bình theo Risk Tier
-- Khách hàng nợ xấu có điểm FICO thấp hơn nhóm bình thường không?
-- =========================

SELECT 
    r.risk_tier                     AS Muc_Rui_Ro,
    COUNT(f.loan_id)                AS So_Khoan_Vay,
    ROUND(AVG(c.fico_range_low), 0) AS FICO_Thap_TB,
    ROUND(AVG(c.fico_range_high), 0)AS FICO_Cao_TB,
    ROUND(AVG((c.fico_range_low + c.fico_range_high) / 2.0), 0) AS FICO_Trung_Binh,
    ROUND(AVG(c.annual_inc), 0)     AS Thu_Nhap_TB,
    ROUND(AVG(f.dti), 2)           AS DTI_TB
FROM Fact_Loans f
JOIN Dim_Customers  c ON f.customer_id = c.customer_id
JOIN Dim_CreditRisk r ON f.risk_id     = r.risk_id
GROUP BY r.risk_tier
ORDER BY FICO_Trung_Binh DESC;

-- =========================
-- 15. Tổng hợp Dashboard - KPI tổng quan (1 query duy nhất)
-- Dùng để hiển thị các card số liệu chính trong Power BI
-- =========================

SELECT
    COUNT(f.loan_id)                                    AS Tong_Khoan_Vay,
    ROUND(SUM(f.loan_amnt) / 1000000.0, 2)             AS Tong_Giai_Ngan_Trieu_USD,
    ROUND(SUM(f.out_prncp) / 1000000.0, 2)             AS Tong_Du_No_Trieu_USD,
    ROUND(AVG(f.int_rate), 2)                           AS Lai_Suat_TB_Phan_Tram,
    ROUND(AVG(f.dti), 2)                               AS DTI_TB,
    SUM(CASE WHEN r.npl_flag = 1 THEN 1 ELSE 0 END)    AS Tong_Khoan_No_Xau,
    ROUND(
        SUM(CASE WHEN r.npl_flag = 1 THEN f.loan_amnt ELSE 0 END) * 100.0
        / NULLIF(SUM(f.loan_amnt), 0), 2
    )                                                   AS NPL_Ratio_Phan_Tram,
    ROUND(
        SUM(f.total_pymnt) * 100.0
        / NULLIF(SUM(f.loan_amnt), 0), 2
    )                                                   AS Repayment_Rate_Phan_Tram,
    ROUND(SUM(f.recoveries) / 1000000.0, 2)            AS Tong_Thu_Hoi_Trieu_USD
FROM Fact_Loans f
JOIN Dim_CreditRisk r ON f.risk_id = r.risk_id;