import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import os


CSV_PATH = "C:/Năm 3 kì 2/HQT_CSDL/data_hqtcsdl.csv"
OUTPUT_DIR = "C:/Năm 3 kì 2/HQT_CSDL/Dataset/outputs/charts"

os.makedirs(OUTPUT_DIR, exist_ok=True)

# LOAD DATA

df = pd.read_csv(CSV_PATH, low_memory=False)
print("Load xong dữ liệu")

# CLEAN DATA


# numeric dạng %
df["int_rate"] = pd.to_numeric(
    df["int_rate"].astype(str).str.replace("%","", regex=False),
    errors="coerce"
)

# term, emp_length dạng text → số
df["term"] = pd.to_numeric(df["term"].astype(str).str.extract(r'(\d+)')[0], errors="coerce")
df["emp_length"] = pd.to_numeric(df["emp_length"].astype(str).str.extract(r'(\d+)')[0], errors="coerce")

# datetime
df["issue_d"] = pd.to_datetime(df["issue_d"], errors="coerce")
df["last_pymnt_d"] = pd.to_datetime(df["last_pymnt_d"], errors="coerce")
df["earliest_cr_line"] = pd.to_datetime(df["earliest_cr_line"], errors="coerce")

# tạo time features
df["issue_year"] = df["issue_d"].dt.year
df["issue_month"] = df["issue_d"].dt.month
df["issue_quarter"] = df["issue_d"].dt.quarter

# HÀM VẼ

def hist(col):
    print(f"Hist: {col}")
    plt.figure()
    sns.histplot(df[col].dropna(), bins=50)
    plt.title(col)
    plt.savefig(f"{OUTPUT_DIR}/{col}_hist.png")
    plt.close()

def line(col):
    print(f"Line: {col}")
    plt.figure()

    if col in ["issue_d", "last_pymnt_d"]:
        series = df[col].dropna().dt.to_period("M").value_counts().sort_index()
    else:
        series = df.groupby(col).size().sort_index()

    series.plot()
    plt.title(col)
    plt.savefig(f"{OUTPUT_DIR}/{col}_line.png")
    plt.close()

def bar(col):
    print(f"Bar: {col}")
    plt.figure()

    series = df[col].dropna()

    
    # BUSINESS SORT


    if col == "grade":
        order = ["A","B","C","D","E","F","G"]
        vc = series.value_counts().reindex(order)

    elif col == "loan_status":
        order = [
            "Fully Paid",
            "Current",
            "In Grace Period",
            "Late (16-30 days)",
            "Late (31-120 days)",
            "Default",
            "Charged Off"
        ]
        vc = series.value_counts().reindex(order)

    elif col == "issue_month":
        vc = series.value_counts().sort_index()

    elif col == "issue_quarter":
        vc = series.value_counts().sort_index()

    # AUTO DETECT NUMERIC
    else:
        converted = pd.to_numeric(series, errors="coerce")

        if converted.notna().sum() > 0.8 * len(series):
            vc = converted.value_counts().sort_index()
        else:
            vc = series.value_counts().head(10)

    vc.plot(kind="bar")
    plt.title(col)
    plt.savefig(f"{OUTPUT_DIR}/{col}_bar.png")
    plt.close()

# VẼ 32 CHART (-id)

print(df["issue_d"].head(20))
print(df["issue_year"].unique())
print("Bắt đầu vẽ chart...")

# 1. ĐỊNH DANH & THỜI GIAN (4, bỏ id)
line("issue_d")
line("issue_year")
bar("issue_month")
bar("issue_quarter")

# 2. KHOẢN VAY (5)
hist("loan_amnt")
bar("term")
hist("int_rate")
bar("grade")
bar("purpose")

# 3. KHÁCH HÀNG (4)
hist("annual_inc")
bar("emp_length")
bar("home_ownership")
bar("addr_state")

# 4. RỦI RO TÀI CHÍNH (5)
hist("dti")
hist("delinq_2yrs")
hist("fico_range_low")
hist("fico_range_high")
hist("pub_rec")

# 5. TÍN DỤNG (8)
hist("revol_bal")
hist("revol_util")
hist("total_acc")
hist("total_bc_limit")
hist("max_bal_bc")
hist("il_util")
hist("all_util")
hist("mort_acc")

# 6. THANH TOÁN (4)
hist("total_pymnt")
hist("out_prncp")
hist("recoveries")
line("last_pymnt_d")

# 7. TRẠNG THÁI (1)
bar("loan_status")

print("HOÀN TẤT!")
print("Chart lưu tại:", OUTPUT_DIR)