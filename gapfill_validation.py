"""Evaluate simple gap-filling methods on simulated missing bike-hire days.

Run from the repository root:
    python gapfill_validation.py

The source has no missing daily hire values after duplicate-date checks. This
script therefore masks complete historical blocks to compare retrospective
recovery methods. Results apply to this bike-hire dataset, not traffic surveys.
"""

from pathlib import Path
import random

import numpy as np
import pandas as pd


INPUT = Path("London_COVID_bikes.csv")
OUTPUT = Path("gapfill_validation_metrics.csv")
SEED = 2026
WINDOWS_PER_LENGTH = 50
GAP_LENGTHS = (1, 3, 7, 14)


def load_daily_series(path: Path) -> pd.Series:
    data = pd.read_csv(path, parse_dates=["date"])
    required = {"date", "Hires"}
    if not required.issubset(data.columns):
        raise ValueError(f"Input must contain columns: {sorted(required)}")
    if data["date"].isna().any() or data["Hires"].isna().any():
        raise ValueError("Resolve missing dates or hire values before validation")

    conflicting = data.groupby("date")["Hires"].nunique().gt(1)
    if conflicting.any():
        raise ValueError("Repeated dates have conflicting hire counts")

    daily = data.sort_values("date").drop_duplicates("date", keep="first")
    daily = daily.set_index("date")["Hires"].astype(float)
    full_index = pd.date_range(daily.index.min(), daily.index.max(), freq="D")
    daily = daily.reindex(full_index)
    if daily.isna().any():
        raise ValueError("Source has missing calendar dates; review before simulation")
    daily.index.name = "date"
    return daily


def sample_windows(n: int, gap: int, rng: random.Random) -> list[int]:
    # Keep a 14-day margin so all test windows are interior and have prior data.
    candidates = list(range(14, n - gap - 14))
    rng.shuffle(candidates)
    selected: list[int] = []
    for start in candidates:
        if all(start + gap <= prior or prior + gap <= start for prior in selected):
            selected.append(start)
            if len(selected) == WINDOWS_PER_LENGTH:
                break
    if len(selected) < WINDOWS_PER_LENGTH:
        raise ValueError(f"Could not sample {WINDOWS_PER_LENGTH} non-overlapping windows")
    return selected


def recover_linear(masked: pd.Series) -> pd.Series:
    return masked.interpolate(method="linear", limit_area="inside")


def recover_weekly(masked: pd.Series, start: int, gap: int) -> pd.Series:
    recovered = masked.copy()
    for position in range(start, start + gap):
        prior_week = position - 7
        if prior_week < 0 or pd.isna(recovered.iloc[prior_week]):
            raise ValueError("Weekly baseline lacks an observed or recovered prior value")
        recovered.iloc[position] = recovered.iloc[prior_week]
    return recovered


def main() -> None:
    actual = load_daily_series(INPUT)
    rng = random.Random(SEED)
    rows = []

    for gap in GAP_LENGTHS:
        for start in sample_windows(len(actual), gap, rng):
            masked = actual.copy()
            truth = actual.iloc[start : start + gap].to_numpy()
            masked.iloc[start : start + gap] = np.nan

            methods = {
                "Linear interpolation": recover_linear(masked),
                "Same weekday, prior week": recover_weekly(masked, start, gap),
            }
            for method, recovered in methods.items():
                predicted = recovered.iloc[start : start + gap].to_numpy()
                errors = predicted - truth
                rows.append(
                    {
                        "gap_days": gap,
                        "method": method,
                        "actual": truth,
                        "errors": errors,
                    }
                )

    summary = []
    for gap in GAP_LENGTHS:
        for method in ("Linear interpolation", "Same weekday, prior week"):
            result = [
                row for row in rows
                if row["gap_days"] == gap and row["method"] == method
            ]
            errors = np.concatenate([row["errors"] for row in result])
            actual_values = np.concatenate([row["actual"] for row in result])
            summary.append(
                {
                    "gap_days": gap,
                    "method": method,
                    "simulated_windows": len(result),
                    "masked_days": len(errors),
                    "MAE_hires": float(np.mean(np.abs(errors))),
                    "RMSE_hires": float(np.sqrt(np.mean(errors**2))),
                    "WAPE_percent": float(
                        np.sum(np.abs(errors)) / np.sum(np.abs(actual_values)) * 100
                    ),
                }
            )

    output = pd.DataFrame(summary)
    output.to_csv(OUTPUT, index=False, float_format="%.2f")
    print(f"Source: {actual.index.min().date()} to {actual.index.max().date()}")
    print(f"Seed: {SEED}; windows per gap length: {WINDOWS_PER_LENGTH}")
    print(output.to_string(index=False, formatters={
        "MAE_hires": "{:,.0f}".format,
        "RMSE_hires": "{:,.0f}".format,
        "WAPE_percent": "{:.2f}%".format,
    }))
    print(f"Saved: {OUTPUT}")


if __name__ == "__main__":
    main()
