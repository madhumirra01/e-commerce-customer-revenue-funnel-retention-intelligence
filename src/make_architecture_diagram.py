"""Generates docs/architecture.png. Run: python src/make_architecture_diagram.py"""
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
from config import ROOT

fig, ax = plt.subplots(figsize=(14, 6.2)); ax.axis("off"); ax.set_xlim(0, 14); ax.set_ylim(0, 6.2)

def box(x, y, w, h, title, sub, color):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.05,rounding_size=0.12",
                                fc=color, ec="#1d3557", lw=1.3))
    ax.text(x + w/2, y + h - 0.32, title, ha="center", va="center", fontsize=10.5, weight="bold", color="#1d3557")
    ax.text(x + w/2, y + h/2 - 0.2, sub, ha="center", va="center", fontsize=8.3, color="#222")

def arrow(x1, y1, x2, y2):
    ax.annotate("", xy=(x2, y2), xytext=(x1, y1), arrowprops=dict(arrowstyle="-|>", lw=1.6, color="#1d3557"))

box(0.2, 2.4, 2.3, 1.5, "1. SOURCE", "Olist Kaggle\n8 CSV files\n(~100k orders)", "#e9f5fb")
box(3.0, 2.4, 2.6, 1.5, "2. PYTHON", "Pandas / NumPy\nclean + validate\ndata_quality_report", "#d7ecf7")
box(6.1, 2.4, 2.6, 1.5, "3. POSTGRESQL", "schema `olist`\n7 tables, PK/FK\nviews (v_*, bi_*)", "#bfe0f2")
box(9.2, 3.9, 2.6, 1.5, "4a. SQL ANALYSIS", "CTEs, window fns\nRFM, cohorts, funnel", "#fff1cc")
box(9.2, 0.9, 2.6, 1.5, "4b. POWER BI", "Power Query + DAX\n5-page dashboard", "#ffe0b3")
box(12.2, 2.4, 1.6, 1.5, "5. OUTPUT", "Insights\nReport\nActions", "#d9f2e4")
box(3.0, 0.3, 2.6, 1.1, "EDA", "Matplotlib / Seaborn\nfigures", "#eef")
arrow(2.5, 3.15, 3.0, 3.15); arrow(5.6, 3.15, 6.1, 3.15)
arrow(8.7, 3.4, 9.2, 4.4); arrow(8.7, 2.9, 9.2, 1.9)
arrow(11.8, 4.5, 12.4, 3.9); arrow(11.8, 1.9, 12.4, 2.4)
arrow(4.3, 2.4, 4.3, 1.4)
ax.text(7, 5.9, "E-Commerce Customer Revenue, Funnel & Retention Intelligence - Architecture",
        ha="center", fontsize=13, weight="bold", color="#1d3557")
plt.savefig(ROOT / "docs" / "architecture.png", dpi=170, bbox_inches="tight"); print("saved docs/architecture.png")
