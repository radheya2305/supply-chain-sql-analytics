"""
run_all.py - Supply Chain SQL Analytics (Olist e-commerce data)

What it does:
  1. Downloads the public Olist dataset into data/ (first run only).
  2. Loads it into an in-memory DuckDB database (sql/00_load_tables.sql).
  3. Runs every analysis query in sql/ and saves each result to outputs/*.csv.
  4. Draws four charts into charts/ and writes outputs/key_findings.md.

Run from this folder:
    pip install -r requirements.txt
    python run_all.py
"""

import glob
import os
import ssl
import sys
import urllib.request

import duckdb
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)

FILES = [
    "olist_orders_dataset.csv",
    "olist_order_items_dataset.csv",
    "olist_products_dataset.csv",
    "olist_sellers_dataset.csv",
    "olist_customers_dataset.csv",
    "olist_order_reviews_dataset.csv",
    "product_category_name_translation.csv",
]
MIRROR = "https://raw.githubusercontent.com/spdrio/Brazilian-E-Commerce-Public-Dataset-by-Olist/master/files/"
KAGGLE = "https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce"


def ssl_context():
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        return ssl.create_default_context()


def download_data():
    os.makedirs("data", exist_ok=True)
    missing = [f for f in FILES if not os.path.exists(os.path.join("data", f))]
    if not missing:
        return
    print(f"Downloading {len(missing)} data files (about 65 MB, first run only)...")
    ctx = ssl_context()
    for f in missing:
        try:
            with urllib.request.urlopen(MIRROR + f, context=ctx, timeout=120) as r, open(os.path.join("data", f), "wb") as out:
                out.write(r.read())
            print("  got", f)
        except Exception as e:  # noqa: BLE001
            print(f"\nCould not download {f}: {e}")
            print(f"Download the dataset manually from {KAGGLE}")
            print("unzip it, and put these CSV files in the data/ folder:")
            for name in FILES:
                print("   ", name)
            sys.exit(1)


def run_queries(con):
    con.execute(open("sql/00_load_tables.sql").read())
    results = {}
    os.makedirs("outputs", exist_ok=True)
    for path in sorted(glob.glob("sql/[0-9][0-9]_*.sql")):
        name = os.path.basename(path)[:-4]
        if name.startswith("00_"):
            continue
        df = con.execute(open(path).read()).df()
        df.to_csv(os.path.join("outputs", name + ".csv"), index=False)
        results[name] = df
        print(f"  {name}: {len(df)} rows -> outputs/{name}.csv")
    return results


def draw_charts(r):
    os.makedirs("charts", exist_ok=True)
    plt.rcParams.update({"font.size": 10, "axes.spines.top": False, "axes.spines.right": False})

    # 1. Demand vs delivery reliability
    d, otd = r["02_monthly_demand_trend"], r["03_on_time_delivery_by_month"]
    fig, (a1, a2) = plt.subplots(2, 1, figsize=(10, 6), sharex=True)
    a1.bar(d["order_month"].astype(str).str[:7], d["orders"], color="#9DB4D3", label="Orders")
    a1.plot(d["order_month"].astype(str).str[:7], d["orders_3mo_avg"], color="#1F3864", lw=2, label="3-month average")
    a1.set_ylabel("Orders")
    a1.legend(frameon=False)
    a1.set_title("Monthly orders (top) and on-time delivery % (bottom): reliability dipped in Nov 2017 and Feb-Mar 2018")
    a2.plot(otd["order_month"].astype(str).str[:7], otd["on_time_pct"], marker="o", color="#C0392B")
    a2.set_ylabel("On-time delivery %")
    a2.set_ylim(75, 100)
    a2.tick_params(axis="x", rotation=60)
    fig.tight_layout()
    fig.savefig("charts/1_demand_vs_on_time.png", dpi=150)
    plt.close(fig)

    # 2. Late deliveries vs review score
    v = r["10_late_delivery_vs_review_score"]
    fig, ax = plt.subplots(figsize=(8, 4.5))
    labels = v["delivery_bucket"].str[3:]
    bars = ax.bar(labels, v["avg_review_score"], color=["#2E86C1"] + ["#C0392B"] * (len(v) - 1))
    for b, val in zip(bars, v["avg_review_score"]):
        ax.text(b.get_x() + b.get_width() / 2, val + 0.05, f"{val:.2f}", ha="center")
    ax.set_ylim(0, 5)
    ax.set_ylabel("Average review score (1-5)")
    ax.set_title("Review scores fall sharply once an order is even a few days late")
    fig.tight_layout()
    fig.savefig("charts/2_late_delivery_vs_reviews.png", dpi=150)
    plt.close(fig)

    # 3. Pareto of late orders by seller
    p = r["07_late_order_pareto_by_seller"]
    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.plot(p["pct_of_active_sellers"], p["cum_pct_of_late_orders"], color="#1F3864", lw=2)
    ax.axhline(50, color="grey", ls="--", lw=1)
    ax.set_xlabel("% of active sellers (worst first)")
    ax.set_ylabel("Cumulative % of late orders")
    ax.set_title("A small group of sellers accounts for half of all late orders")
    fig.tight_layout()
    fig.savefig("charts/3_late_order_pareto.png", dpi=150)
    plt.close(fig)

    # 4. ABC-XYZ matrix (share of revenue)
    x = r["09_category_xyz_demand_variability"]
    grid = x.pivot_table(index="abc_class", columns="xyz_class", values="revenue", aggfunc="sum").reindex(
        index=["A", "B", "C"], columns=["X", "Y", "Z"]).fillna(0)
    share = 100 * grid / grid.values.sum()
    counts = x.pivot_table(index="abc_class", columns="xyz_class", values="category", aggfunc="count").reindex(
        index=["A", "B", "C"], columns=["X", "Y", "Z"]).fillna(0)
    fig, ax = plt.subplots(figsize=(6, 4.5))
    ax.imshow(share.values, cmap="Blues")
    for i in range(3):
        for j in range(3):
            ax.text(j, i, f"{share.values[i, j]:.1f}% rev\n{int(counts.values[i, j])} " + ("category" if int(counts.values[i, j]) == 1 else "categories"), ha="center", va="center",
                    color="white" if share.values[i, j] > 20 else "black", fontsize=9)
    ax.set_xticks(range(3), ["X (steady)", "Y (variable)", "Z (erratic)"])
    ax.set_yticks(range(3), ["A (top 80% rev)", "B (next 15%)", "C (last 5%)"])
    ax.set_title("ABC-XYZ: where planning effort should go")
    fig.tight_layout()
    fig.savefig("charts/4_abc_xyz_matrix.png", dpi=150)
    plt.close(fig)
    print("  charts saved to charts/")


def write_findings(con, r):
    overall = con.execute("SELECT COUNT(*), ROUND(100*AVG(on_time),1), MEDIAN(lead_time_days) FROM delivered_orders").fetchone()
    v = r["10_late_delivery_vs_review_score"].set_index("delivery_bucket")
    root = r["12_late_root_cause_seller_vs_carrier"].set_index("outcome")["orders"]
    late_total = root["Late - seller handed off late"] + root["Late - seller on time, transit missed"]
    transit_share = 100 * root["Late - seller on time, transit missed"] / late_total
    p = r["07_late_order_pareto_by_seller"]
    half = p[p["cum_pct_of_late_orders"] >= 50].iloc[0]
    lane = r["05_late_delivery_by_lane"].set_index("lane").loc["SP -> RJ"]
    otd = r["03_on_time_delivery_by_month"].set_index(r["03_on_time_delivery_by_month"]["order_month"].astype(str).str[:7])
    fr = r["11_freight_cost_by_region"].set_index("region")
    x = r["09_category_xyz_demand_variability"]
    a = x[x["abc_class"] == "A"]
    a_rev = 100 * a["revenue"].sum() / x["revenue"].sum()

    lines = [
        "# Key findings (generated by run_all.py)",
        "",
        f"- Scope: {overall[0]:,} delivered orders, Jan 2017 - Aug 2018. On-time delivery {overall[1]}%; median lead time {overall[2]:.0f} days.",
        f"- Late deliveries hurt satisfaction: on-time orders average {v.loc['1. On time or early','avg_review_score']:.2f} stars; "
        f"4-7 days late averages {v.loc['3. 4-7 days late','avg_review_score']:.2f}, and {v.loc['3. 4-7 days late','pct_1_or_2_star']:.0f}% of those reviews are 1-2 stars "
        f"(vs {v.loc['1. On time or early','pct_1_or_2_star']:.1f}% when on time).",
        f"- Root cause: {transit_share:.0f}% of late orders were handed to the carrier on time by the seller and still arrived late, so transit is the bigger lever than seller handoff.",
        f"- Concentration: {int(half['seller_rank'])} sellers ({half['pct_of_active_sellers']:.1f}% of active sellers) account for 50% of late orders.",
        f"- Worst lane: SP -> RJ carries {lane['pct_of_all_orders']}% of orders but {lane['pct_of_all_late_orders']}% of late orders ({lane['late_pct']}% late).",
        f"- Peak stress: on-time fell to {otd.loc['2017-11','on_time_pct']}% in Nov 2017 (Black Friday month) and {otd.loc['2018-03','on_time_pct']}% in Mar 2018.",
        f"- Freight: {fr.loc['North','freight_pct_of_price']}% of item price in the North and {fr.loc['Northeast','freight_pct_of_price']}% in the Northeast, vs {fr.loc['Southeast','freight_pct_of_price']}% in the Southeast.",
        f"- ABC-XYZ: {len(a)} of {len(x)} categories make up {a_rev:.0f}% of revenue; "
        f"{(a['xyz_class']=='X').sum()} of them have steady demand (X), {(a['xyz_class']=='Y').sum()} are variable (Y), {(a['xyz_class']=='Z').sum()} erratic (Z).",
    ]
    open("outputs/key_findings.md", "w").write("\n".join(lines) + "\n")
    print("\n".join(lines[2:]))


if __name__ == "__main__":
    download_data()
    con = duckdb.connect()
    print("Running queries...")
    results = run_queries(con)
    draw_charts(results)
    print("\nKey findings (also saved to outputs/key_findings.md):")
    write_findings(con, results)
