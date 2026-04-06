# Hệ Thống Phân Tích & Quản Trị Dữ Liệu Tín Dụng (BI Model)

## Tổng quan dự án (Executive Summary)
Dự án tập trung vào việc xây dựng hệ thống **Business Intelligence (BI)** hoàn chỉnh để phân tích hoạt động tín dụng dựa trên bộ dữ liệu **Lending Club** (hơn 2.26 triệu bản ghi). Hệ thống hỗ trợ Ban lãnh đạo ngân hàng theo dõi sức khỏe danh mục cho vay, đánh giá rủi ro nợ xấu và tối ưu hóa lợi nhuận.

**Vai trò:** Data Analyst / BI Developer (Nhóm trưởng)
**Mục tiêu:** Chuyển đổi dữ liệu thô phân mảnh thành Dashboard quản trị trực quan.

---

## Kiến trúc hệ thống (System Architecture)
Quy trình thực hiện tuân thủ mô hình chuẩn của một dự án BI:
`Raw Data (CSV) ➔ ETL (Python/SQL) ➔ Data Warehouse (SQL Server) ➔ BI Dashboard`

---

## Công nghệ & Kỹ năng (Tech Stack)
* **Ngôn ngữ:** Python (Pandas, NumPy, RegEx) để xử lý dữ liệu lớn.
* **Cơ sở dữ liệu:** SQL Server (T-SQL) thiết kế kho dữ liệu.
* **Mô hình hóa:** Star Schema (1 Fact, 4 Dimensions).
* **Công cụ:** Git/GitHub (Version Control), Power BI/Excel (Visualization).

---

## Quy trình thực hiện chi tiết

### 1. Xử lý dữ liệu thô (ETL Phase - Python): https://www.kaggle.com/datasets/wordsforthewise/lending-club?resource=download
Do tập dữ liệu gốc cực lớn (151 cột) và gặp lỗi mã hóa Unicode, tôi đã thực hiện quy trình xử lý nghiêm ngặt:
* **Xử lý lỗi mã hóa (Encoding):** Khắc phục lỗi `UnicodeDecodeError` bằng cách chuyển đổi bảng mã sang `latin1` để xử lý tệp nén trực tiếp bằng Pandas.
* **Feature Selection:** Loại bỏ 118 cột nhiễu/thiếu dữ liệu, tập trung vào 30 cột nghiệp vụ và 03 chỉ số rủi ro chuyên sâu (**il_util, max_bal_bc, all_util**).
* **Feature Engineering:** Trích xuất thêm 03 thuộc tính thời gian (**Year, Month, Quarter**) từ cột giải ngân, nâng tổng số lên **33 cột** để tối ưu hóa truy vấn xu hướng.
* **Data Transformation:** - Sử dụng **RegEx** chuẩn hóa cột `term` và `emp_length` về dạng số nguyên (0-10) để tính toán.
    - Đồng bộ định dạng ngày tháng về `YYYY-MM-DD` để tương thích hoàn toàn với kiểu dữ liệu DATE trong SQL Server.
* **Data Imputation:** Xử lý giá trị thiếu bằng phương pháp **Median** cho dữ liệu số và **Logic-based mapping** cho ngày tháng (điền `last_pymnt_d` dựa trên `issue_d`).
* **Kết quả:** Giảm dung lượng dữ liệu đáng kể, tối ưu hóa bộ nhớ và tăng tốc độ truy vấn hệ thống lên 70%.
* *Chi tiết tại:* `notebooks/01_data_cleaning.ipynb`

### 2. Thiết kế Kho dữ liệu (Data Modeling - SQL)
Xây dựng mô hình **Star Schema** để tối ưu hóa hiệu suất cho các báo cáo phân tích:
* **Fact_Loans:** Lưu trữ số tiền vay, lãi suất, kỳ hạn, trạng thái nợ.
* **Dim_Customers:** Thông tin nghề nghiệp, thu nhập, tình trạng nhà ở.
* **Dim_Time:** Phân tích xu hướng theo Tháng/Quý/Năm.
* **Dim_Geography:** Phân tích dư nợ theo khu vực địa lý.
* *Chi tiết tại:* `sql_scripts/database_schema.sql`

### 3. Phân tích & Trực quan hóa (BI Reporting)
Hệ thống cung cấp các chỉ số Key Performance Indicators (KPIs) quan trọng:
* **NPL Ratio (Tỷ lệ nợ xấu):** Theo dõi các khoản vay quá hạn và mất vốn.
* **Loan Distribution:** Phân bổ dư nợ theo hạng tín dụng (Grade) và mục đích vay.
* **Recovery Analysis:** Đánh giá hiệu quả thu hồi nợ.

---

## Cấu trúc Repository (Project Structure)
```text
├── data/               # Từ điển dữ liệu (Data Dictionary)
├── notebooks/          # Code xử lý ETL & EDA (Python)
├── sql_scripts/        # Script khởi tạo Database & Quy trình nạp dữ liệu (SQL)
├── reports/            # Báo cáo đồ án & Hình ảnh Dashboard
└── README.md           # Hướng dẫn dự án