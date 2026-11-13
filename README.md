# London Bike Hire Demand Analysis

A time-series study of London's daily bike-hire demand from 2010 to 2023. The project examines seasonality and associations between COVID-era policy periods and hire volumes, compares monthly forecasting methods, and evaluates recovery methods on simulated missing-data blocks.

This is a bike-share demand analysis. It does not use traffic survey counts or footage.

## Why the analysis matters

Bike-hire demand forecasts can inform planning for bike availability and operational capacity. A forecast with large systematic overestimation could lead to poor allocation decisions. This project therefore reports errors against a seasonal-naive benchmark rather than presenting a forecast as useful solely because a model can be fitted.

## Questions

- How did hire volumes vary by season and across the study period?
- Which COVID-era policy indicators were associated with changes in demand?
- How did seasonal forecasting methods perform on unseen months?
- How accurately can short, simulated gaps in daily hire data be recovered?

## Data and checks

The analysis combines the TfL bike-hire dataset with UK Government COVID policy indicators.

- Daily observations run from 30 July 2010 to 30 September 2023
- July 2010 is excluded from monthly forecasting because it is incomplete
- The source contains a repeated date with identical hire counts but conflicting policy flags; the forecast series keeps one hire observation for that date
- The backtest checks date coverage and monthly completeness before fitting models
- The gap-recovery exercise first confirms complete daily coverage, then masks known values for evaluation

## Methods

The policy analysis uses multiple linear regression and ANOVA with seasonal terms and policy indicators. Results describe statistical associations and do not establish that a policy caused a change in hire demand.

### Monthly forecast comparison

Daily hires are aggregated to complete monthly totals. The analysis compares a seasonal-naive benchmark with seasonal-trend regression using a linear time trend and monthly effects. The final 12 months, October 2022 to September 2023, are held out from model fitting. MAE, RMSE and MAPE are calculated for that period. Five-year and three-year training windows are sensitivity checks.

| Model | MAE | RMSE | MAPE |
|---|---:|---:|---:|
| Seasonal-naive benchmark | 299,603 | 331,406 | 41.78% |
| Seasonal-trend regression, full history | 288,022 | 305,501 | 40.34% |
| Seasonal-trend regression, five-year window | 256,490 | 281,149 | 35.18% |
| Seasonal-trend regression, three-year window | 340,893 | 363,297 | 47.19% |

On this holdout, the five-year window reduced MAE by 14.4% and RMSE by 15.2% against the seasonal-naive benchmark. All three regression windows overestimated total hires for the held-out year by at least 35%. The results show sensitivity to training-window choice and do not establish a reliable operational forecast.

### Simulated missing-data recovery

The source series has complete daily coverage after duplicate-date checks, so the recovery comparison uses simulated gaps rather than observed missing records. With seed 2026, the script masks 50 non-overlapping historical windows at each gap length and compares linear interpolation with a same-weekday prior-week baseline. The baseline repeats the previous week's value through longer gaps. Errors are pooled across masked days.

| Gap length | Method | Windows | MAE | RMSE | WAPE |
|---:|---|---:|---:|---:|---:|
| 1 day | Linear interpolation | 50 | 3,894 | 5,318 | 15.38% |
| 1 day | Same weekday, prior week | 50 | 5,074 | 7,617 | 20.04% |
| 3 days | Linear interpolation | 50 | 4,850 | 6,131 | 18.38% |
| 3 days | Same weekday, prior week | 50 | 5,704 | 7,766 | 21.61% |
| 7 days | Linear interpolation | 50 | 5,675 | 7,540 | 20.60% |
| 7 days | Same weekday, prior week | 50 | 5,342 | 7,531 | 19.39% |
| 14 days | Linear interpolation | 50 | 5,602 | 7,470 | 22.41% |
| 14 days | Same weekday, prior week | 50 | 5,877 | 8,149 | 23.51% |

Linear interpolation had lower MAE for the one-, three- and 14-day simulated gaps; the prior-week baseline had slightly lower MAE for seven-day gaps. Neither method performed best at every gap length. These results apply to this bike-hire dataset and do not establish a method for traffic surveys.

## Operational interpretation

The five-year training window performed best among the methods tested, but the holdout error remained substantial. I would not use these predictions to set staffing or fleet allocations without more backtesting, investigation of changing demand patterns and a clear tolerance for overforecasting.

The gap-recovery comparison is a separate methodological check. It tests recovery of deliberately masked known values, not repair of actual missing observations. The [automated workflow](.github/workflows/validate-gapfill.yml) executes that Python validation; it does not independently rerun the R forecasting analysis.

## Visuals

![Monthly bike-hire demand](monthly_demand_pattern.png)

The R Markdown report includes yearly trends, COVID-period comparisons, a policy timeline and demand distributions.

## Reproduce

Run the forecast comparison from the repository root:

```bash
Rscript monthly_forecast_backtest.R
```

Run the simulated gap-recovery comparison:

```bash
pip install pandas numpy
python gapfill_validation.py
```

Render the full policy analysis:

```r
rmarkdown::render("london_bike_hire_covid_analysis.Rmd")
```

Install the R packages:

```r
install.packages(c("tidyverse", "ggplot2", "dplyr", "lubridate",
                   "forecast", "tsibble", "lmtest", "scales", "rmarkdown"))
```

## Repository contents

- `london_bike_hire_covid_analysis.Rmd`: policy analysis and charts
- `london_bike_hire_covid_analysis.html`: rendered report
- `monthly_forecast_backtest.R`: monthly forecast comparison
- `gapfill_validation.py`: simulated missing-data recovery comparison
- `London_COVID_bikes.csv`: daily hire counts and policy indicators
- `forecast_backtest_metrics.csv` and `forecast_backtest_predictions.csv`: forecast outputs
- `gapfill_validation_metrics.csv`: recovery comparison results
- PNG files: supporting trend, period-comparison and distribution charts

## Scope and limitations

The forecast holdout covers one year, and the models materially overestimated total demand. The simulated gap exercise masks known bike-hire values; it is not evidence of experience with missing traffic-survey counts, data collection technologies, traffic footage or production interpolation methods.
