# London Bike Hire Demand Analysis

A time-series study of London's daily bike-hire demand from 2010 to 2023. The project examines seasonality and associations between COVID-era policy periods and hire volumes, then compares monthly forecasting methods on a held-out year.

This is a bike-share demand analysis. It does not use traffic survey counts or footage.

## Questions

- How did hire volumes vary by season and across the study period?
- Which COVID-era policy indicators were associated with changes in demand?
- How did a seasonal-trend regression compare with a seasonal-naive benchmark on unseen months?

## Data and checks

The analysis combines the TfL bike-hire dataset with UK Government COVID policy indicators.

- Daily observations run from 30 July 2010 to 30 September 2023
- July 2010 is excluded from monthly forecasting because it is incomplete
- The source contains a repeated date with identical hire counts but conflicting policy flags; the forecast series keeps one hire observation for that date
- The backtest checks date coverage and monthly completeness before fitting models
- The backtest stops if required dates or hire values are missing; no interpolation or gap-filling is performed

## Methods

The policy analysis uses multiple linear regression and ANOVA with seasonal terms and policy indicators. Results describe statistical associations and do not establish that a policy caused a change in hire demand.

The forecasting analysis aggregates daily hires to complete monthly totals. It compares:

1. A seasonal-naive benchmark using the same month from the prior year
2. Seasonal-trend regression with a linear time trend and monthly effects, trained on the full available history
3. The same regression fitted on five-year and three-year windows as sensitivity checks

The final 12 months, October 2022 to September 2023, are held out from model fitting. MAE, RMSE and MAPE are calculated for that period.

## Forecast results

| Model | MAE | RMSE | MAPE |
|---|---:|---:|---:|
| Seasonal-naive benchmark | 299,603 | 331,406 | 41.78% |
| Seasonal-trend regression, full history | 288,022 | 305,501 | 40.34% |
| Seasonal-trend regression, five-year window | 256,490 | 281,149 | 35.18% |
| Seasonal-trend regression, three-year window | 340,893 | 363,297 | 47.19% |

On this holdout, the five-year window reduced MAE by 14.4% and RMSE by 15.2% against the seasonal-naive benchmark. All three regression windows overestimated total hires for the held-out year by at least 35%. The results show sensitivity to training-window choice and do not establish a reliable operational forecast.

The policy models found statistically significant positive associations for selected COVID-era indicators. Seasonal terms were also important predictors. See the R Markdown report for coefficients, confidence intervals and model details.

## Reproduce

From the repository root:

```bash
Rscript monthly_forecast_backtest.R
```

The script regenerates `forecast_backtest_predictions.csv` and `forecast_backtest_metrics.csv`. To render the full analysis:

```r
rmarkdown::render("london_bike_hire_covid_analysis.Rmd")
```

Install the required R packages:

```r
install.packages(c("tidyverse", "ggplot2", "dplyr", "lubridate",
                   "forecast", "tsibble", "lmtest", "scales", "rmarkdown"))
```

## Repository contents

- `london_bike_hire_covid_analysis.Rmd`: policy analysis and visualisations
- `monthly_forecast_backtest.R`: reproducible monthly forecast comparison
- `London_COVID_bikes.csv`: daily hire counts and policy indicators
- `forecast_backtest_metrics.csv`: held-out error metrics
- `forecast_backtest_predictions.csv`: actual and predicted monthly hires
- PNG files: supporting trend, period-comparison and distribution charts

## Scope and limitations

The holdout covers one year, and the models materially overestimated total demand. The forecast comparison is an analytical exercise, not a production forecast. The dataset is bike-hire demand rather than classified road-traffic counts, and the project does not assess survey collection technologies, traffic-footage processing or missing-data interpolation.
