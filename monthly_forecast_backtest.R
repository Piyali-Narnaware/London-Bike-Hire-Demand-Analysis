# Monthly demand forecast backtest for the London bike-hire project
# Run from the repository root: Rscript monthly_forecast_backtest.R

suppressPackageStartupMessages({
  library(dplyr)
  library(forecast)
})

source_file <- "London_COVID_bikes.csv"
if (!file.exists(source_file)) {
  stop("Run this script from the repository root; London_COVID_bikes.csv was not found")
}

raw <- read.csv(source_file, stringsAsFactors = FALSE)
raw$date <- as.Date(raw$date)

if (anyNA(raw$date) || anyNA(raw$Hires)) {
  stop("Date or Hires contains missing values; resolve them before forecasting")
}

# The source contains one repeated date with the same hire count but conflicting
# policy flags. Keep one hire observation for that date; policy analysis remains
# in the original RMarkdown file.
duplicate_check <- raw |>
  group_by(date) |>
  summarise(distinct_hire_counts = n_distinct(Hires), .groups = "drop")

if (any(duplicate_check$distinct_hire_counts > 1)) {
  stop("A repeated date has conflicting Hires values; review before aggregation")
}

daily <- raw |>
  arrange(date) |>
  distinct(date, .keep_all = TRUE) |>
  filter(date >= as.Date("2010-08-01")) |>
  mutate(month = as.Date(format(date, "%Y-%m-01")))

# July 2010 is excluded because the source starts on 30 July and is only a
# partial month. All retained months should contain one daily record per date.
month_coverage <- daily |>
  group_by(month) |>
  summarise(days_observed = n_distinct(date), .groups = "drop") |>
  mutate(days_expected = as.integer(format(
    as.Date(paste0(format(month, "%Y-%m"), "-01")) + 32,
    "%d"
  )))
# Use calendar month lengths explicitly for a clear completeness check.
month_coverage$days_expected <- as.integer(
  format(seq(month_coverage$month[1], by = "month", length.out = nrow(month_coverage) + 1)[-1] - 1, "%d")
)
if (any(month_coverage$days_observed != month_coverage$days_expected)) {
  stop("A retained month has missing or duplicate daily observations; review before aggregation")
}

monthly <- daily |>
  group_by(month) |>
  summarise(hires = sum(Hires), .groups = "drop") |>
  arrange(month)

expected_months <- seq(min(monthly$month), max(monthly$month), by = "month")
if (!identical(as.character(monthly$month), as.character(expected_months))) {
  stop("Monthly series has a gap; resolve it before fitting the model")
}

# Hold out the final complete year available in the source.
test_start <- as.Date("2022-10-01")
h <- 12L
test <- monthly |> filter(month >= test_start)
if (nrow(test) != h || max(test$month) != as.Date("2023-09-01")) {
  stop("Expected a 12-month test set from October 2022 to September 2023")
}

make_ts <- function(data) {
  first_month <- data$month[1]
  ts(
    data$hires,
    start = c(
      as.integer(format(first_month, "%Y")),
      as.integer(format(first_month, "%m"))
    ),
    frequency = 12
  )
}

metric_row <- function(name, actual, predicted) {
  data.frame(
    model = name,
    MAE = mean(abs(actual - predicted)),
    RMSE = sqrt(mean((actual - predicted)^2)),
    MAPE_percent = mean(abs((actual - predicted) / actual)) * 100
  )
}

# Seasonal-naive benchmark: each month is forecast from the same month one year earlier.
full_training <- monthly |> filter(month < test_start)
seasonal_naive <- as.numeric(forecast::snaive(make_ts(full_training), h = h)$mean)

fit_seasonal_trend <- function(training_data, label) {
  model <- forecast::tslm(make_ts(training_data) ~ trend + season)
  as.numeric(forecast::forecast(model, h = h)$mean)
}

# Main model uses all available pre-test months. The 5-year and 3-year windows
# are sensitivity checks; they are not selected as a production model.
pred_full <- fit_seasonal_trend(full_training, "full_history")
pred_5y <- fit_seasonal_trend(
  full_training |> filter(month >= as.Date("2017-10-01")),
  "five_year_window"
)
pred_3y <- fit_seasonal_trend(
  full_training |> filter(month >= as.Date("2019-10-01")),
  "three_year_window"
)

actual <- test$hires
predictions <- data.frame(
  month = test$month,
  actual_hires = actual,
  seasonal_naive = seasonal_naive,
  seasonal_trend_full_history = pred_full,
  seasonal_trend_5y_window = pred_5y,
  seasonal_trend_3y_window = pred_3y
)

metrics <- bind_rows(
  metric_row("Seasonal-naive benchmark", actual, seasonal_naive),
  metric_row("Seasonal-trend regression — full history", actual, pred_full),
  metric_row("Seasonal-trend regression — 5-year window", actual, pred_5y),
  metric_row("Seasonal-trend regression — 3-year window", actual, pred_3y)
)

write.csv(predictions, "forecast_backtest_predictions.csv", row.names = FALSE)
write.csv(metrics, "forecast_backtest_metrics.csv", row.names = FALSE)

cat("Monthly series:", format(min(monthly$month), "%Y-%m"), "to",
    format(max(monthly$month), "%Y-%m"), "\n")
cat("Training period:", format(min(full_training$month), "%Y-%m"), "to",
    format(max(full_training$month), "%Y-%m"), "\n")
cat("Held-out period:", format(min(test$month), "%Y-%m"), "to",
    format(max(test$month), "%Y-%m"), "\n\n")
print(transform(metrics, MAE = round(MAE), RMSE = round(RMSE),
                MAPE_percent = round(MAPE_percent, 2)))
