# London Bike Hire Demand — COVID-19 Impact Analysis

![R](https://img.shields.io/badge/R-4.x-blue)
![ggplot2](https://img.shields.io/badge/ggplot2-3.4-orange)
![forecast](https://img.shields.io/badge/forecast-8.21-green)

A behavioural demand analysis of London's bike-sharing scheme from 2010–2023, examining how COVID-19 restrictions reshaped cycling patterns. Uses multiple linear regression, ANOVA, and time-series visualisation to quantify the impact of policy interventions (WFH, Eat Out to Help Out, Rule of 6) on bike hire demand.

---

## Key Findings

| Policy Variable | Coefficient | 95% CI | p-value |
|----------------|-------------|--------|---------|
| Work From Home | +1,769 hires | [1,117, 2,421] | < 0.05 |
| Eat Out to Help Out | +9,869 hires | [6,276, 13,460] | < 0.05 |
| Rule of 6 Indoors | +9,309 hires | [7,367, 11,251] | < 0.05 |

All three COVID-era policies were associated with **statistically significant increases** in bike hire demand, with seasonal factors (month, year, day) being the strongest overall predictors.

---

## Analysis Pipeline

```
┌──────────────────┐     ┌───────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  London Bikes    │────▶│  Pre/During/      │────▶│  Linear          │────▶│  ANOVA Model     │
│  Dataset         │     │  Post-COVID       │     │  Regression      │     │  Comparison      │
│  2010–2023       │     │  Segmentation     │     │  per Policy Var  │     │  + Visualisation │
│  + Policy vars   │     │  (Mar 2020 cut)   │     │  + Interactions  │     │                  │
└──────────────────┘     └───────────────────┘     └──────────────────┘     └──────────────────┘
```

### Methodology

1. **Segmentation** — Data split into pre-COVID (before Mar 2020), during-COVID (Mar 2020–Mar 2021), post-COVID (after Apr 2021)
2. **Policy Variables** — `schools_closed`, `pubs_closed`, `wfh`, `rule_of_6_indoors`, `curfew`, `eat_out_to_help_out`, and others
3. **Regression Models** — Individual linear models for each policy variable, with interaction terms for year, month, and day of week
4. **ANOVA** — Hierarchical model comparison to identify the most influential interaction variables

---

## Results

### Yearly Trends
![Yearly Trends](yearly_bike_hire_trends.png)

### COVID Period Comparison
![COVID Periods](covid_period_comparison.png)

### Monthly Demand Pattern
![Monthly Demand](monthly_demand_pattern.png)

### Policy Timeline
![Policy Timeline](covid_policy_timeline.png)

### Distribution
![Distribution](bike_hire_distribution.png)

---

## Key Insights

- **Peak demand**: Quarter 2 (spring/summer); **lowest**: December–January
- **Mid-week (Tue–Thu)** sees highest daily demand; Sunday lowest
- **WFH** correlated with +1,769 hires — flexible working enabled leisure cycling
- **Eat Out to Help Out** drove the largest single-policy boost (+9,869 hires)
- **Month** was the most significant interaction variable across all policy models (ANOVA)
- All COVID-era policies showed weak positive correlations (7–13%) with demand

---

## Monthly Demand Forecast Backtest

The analysis now includes an out-of-sample monthly demand forecast using the existing daily hire dataset.

- **Series:** Monthly hire totals from August 2010 to September 2023; July 2010 is excluded because the source starts on 30 July
- **Duplicate-date handling:** One date appears twice with the same hire count but conflicting policy flags; the forecasting series keeps one hire observation for that date
- **Test window:** October 2022 to September 2023, held out from model fitting
- **Benchmark:** Seasonal-naive forecast using the same month from the previous year
- **Model:** Seasonal-trend regression with a linear time trend and month effects
- **Sensitivity checks:** The regression is refit on full-history, 5-year and 3-year training windows

### Held-out results

| Forecast | MAE (hires) | RMSE (hires) | MAPE |
|---|---:|---:|---:|
| Seasonal-naive benchmark | 299,603 | 331,406 | 41.78% |
| Seasonal-trend regression, full history | 288,022 | 305,501 | 40.34% |
| Seasonal-trend regression, 5-year window | 256,490 | 281,149 | 35.18% |
| Seasonal-trend regression, 3-year window | 340,893 | 363,297 | 47.19% |

The full-history regression lowered MAE by 3.9% and RMSE by 7.8% versus the seasonal-naive benchmark on this holdout. The 5-year window produced lower errors in this test, while the 3-year window performed worse. All versions overestimated total hires in the held-out year by at least 35%; the result shows that model performance is sensitive to the training window and that this single test year does not establish a reliable operational forecast.

Run the reproducible R analysis from the repository root:

```bash
Rscript monthly_forecast_backtest.R
```

The committed [forecast predictions](forecast_backtest_predictions.csv) and [forecast metrics](forecast_backtest_metrics.csv) show the monthly results. Rerunning the script regenerates both files. It checks daily date coverage, handles the repeated date only after verifying that the hire counts agree, and keeps the alternative training windows as sensitivity checks rather than presenting one as a production-ready model.

## Project Structure

```
├── london_bike_hire_covid_analysis.Rmd    # RMarkdown analysis
├── london_bike_hire_covid_analysis.html   # Rendered HTML report
├── London_COVID_bikes.csv                 # Dataset with policy indicators
├── yearly_bike_hire_trends.png
├── covid_period_comparison.png
├── monthly_demand_pattern.png
├── covid_policy_timeline.png
├── bike_hire_distribution.png
└── README.md
```

---

## Installation & Reproduce

```bash
git clone https://github.com/Piyali-Narnaware/London-Bike-Hire-Demand-Analysis.git
cd London-Bike-Hire-Demand-Analysis
```

Open `london_bike_hire_covid_analysis.Rmd` in RStudio and **Knit to HTML**, or run:

```r
rmarkdown::render("london_bike_hire_covid_analysis.Rmd")
```

### Dependencies

```r
install.packages(c("tidyverse", "ggplot2", "dplyr", "lubridate",
                   "forecast", "tsibble", "lmtest", "scales"))
```

---

## Dataset

- **Source**: Transport for London (TfL) cycling data + UK Government COVID policy tracker
- **Period**: 2010–2023 (13 years)
- **Frequency**: Daily bike hire counts
- **Policy Variables**: 10+ binary indicators for COVID-19 restriction phases
