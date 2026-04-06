# interdaily-stability-analysis
R utilities for computing and visualizing Interdaily Stability (IS), a metric of how consistently 24-hour activity patterns repeat across days. Includes simulation, aggregation, IS calculation, and plotting functions, with examples showing differences under varying signal-to-noise conditions. Suitable for actigraphy and circadian rhythm analysis.

# Usage

This repository provides R functions for computing and visualizing **Interdaily Stability (IS)**, a quantitative measure of how consistently a 24-hour activity pattern repeats across days. The main script defines utilities for data simulation, aggregation, IS calculation, plotting, and interpretation, and the example script demonstrates how IS changes under different signal-to-noise conditions.  

## 1. Prepare the main functions

First, load the main utility script.

```r
source("interdaily_stability.R")
```

This script provides the following main functions: `generate_activity_data()`, `aggregate_activity()`, `calc_IS()`, `get_daily_profile()`, `plot_activity_timeseries()`, `plot_daily_profile()`, `describe_IS()`, and `check_IS_example()`. 

The script also checks for required packages and installs missing ones automatically before loading them. Required packages are `dplyr`, `lubridate`, `ggplot2`, and `patchwork`. 

## 2. Simulate activity data

You can generate synthetic circadian activity data using `generate_activity_data()`. The simulated signal includes a 24-hour cosine rhythm, optional day-to-day trend, and additive Gaussian noise. Negative values are clipped to zero. 

Example:

```r
df <- generate_activity_data(
  n_days = 14,
  epoch = "hour",
  baseline = 1.5,
  amplitude = 1.0,
  peak_hour = 14,
  noise_sd = 0.2,
  trend = 0,
  seed = 1
)
```

This creates a data frame with:

* `time`: POSIXct timestamps in Asia/Tokyo
* `METs`: simulated activity values 

## 3. Aggregate activity data

If needed, you can aggregate activity data to regular hourly or minute-level epochs using `aggregate_activity()`. This is useful when the original data are sampled more finely or irregularly. The function groups data by floored time epochs and returns the mean value within each epoch. 

Example:

```r
df_hourly <- aggregate_activity(df, value_col = "METs", epoch = "hour")
```

## 4. Compute Interdaily Stability

Use `calc_IS()` to compute the IS value. Internally, the function aggregates the data, calculates the mean activity at each epoch of the day, and applies the standard IS formula. 

Example:

```r
res <- calc_IS(df, value_col = "METs", epoch = "hour")
res$IS
```

The returned object includes:

* `IS`: computed Interdaily Stability
* `N`: total number of epochs
* `p`: number of epochs per day
* `mean_overall`: grand mean
* `profile`: mean activity at each epoch of day
* `data_used`: aggregated data used for the calculation 

## 5. Obtain the mean daily profile

You can calculate the average 24-hour activity profile using `get_daily_profile()`. This function averages activity values at the same time of day across all available days. 

Example:

```r
profile <- get_daily_profile(df, value_col = "METs", epoch = "hour")
head(profile)
```

## 6. Plot the activity time series

The function `plot_activity_timeseries()` creates a line plot of the full activity time series. 

Example:

```r
plot_activity_timeseries(df, value_col = "METs")
```

## 7. Plot the mean daily profile

The function `plot_daily_profile()` plots the average daily pattern, with hour-of-day or minute-of-day on the x-axis and mean activity on the y-axis. 

Example:

```r
plot_daily_profile(df, value_col = "METs", epoch = "hour")
```

## 8. Interpret the IS value

The function `describe_IS()` returns a plain-English interpretation of the computed IS value. The script uses heuristic thresholds:

* `IS >= 0.6`: high stability
* `IS >= 0.3`: moderate stability
* `IS < 0.3`: low stability 

Example:

```r
describe_IS(res$IS)
```

## 9. Run the full example

The easiest way to test the workflow is to use `check_IS_example()`. This function performs the full pipeline: simulation, IS calculation, console output, and two stacked plots showing the activity time series and the average 24-hour profile. 

Example:

```r
check_IS_example(
  n_days = 14,
  epoch = "hour",
  baseline = 1.5,
  amplitude = 1.0,
  peak_hour = 14,
  noise_sd = 0.2,
  trend = 0,
  seed = 1
)
```

## 10. Compare high and low IS cases

After loading `interdaily_stability.R`, you can run `is_comparison_example.R` to compare two simulated scenarios:

* a high-IS case with strong circadian amplitude and low noise
* a low-IS case with weak amplitude and high noise 

Run:

```r
source("interdaily_stability.R")
source("is_comparison_example.R")
```

In the comparison script, the first example uses a large amplitude and low noise to generate a stable rhythm, whereas the second uses a small amplitude and high noise to produce an irregular pattern. The script then prints both IS values and their interpretations for direct comparison. 

## 11. Example workflow

A typical workflow is:

```r
source("interdaily_stability.R")

df <- generate_activity_data(
  n_days = 14,
  epoch = "hour",
  baseline = 1.5,
  amplitude = 1.0,
  peak_hour = 14,
  noise_sd = 0.2,
  trend = 0,
  seed = 1
)

res <- calc_IS(df, value_col = "METs", epoch = "hour")
print(res$IS)
print(describe_IS(res$IS))

plot_activity_timeseries(df, value_col = "METs")
plot_daily_profile(df, value_col = "METs", epoch = "hour")
```

## 12. Execution example

For a quick demonstration, first run `interdaily_stability.R` to load the functions, and then run `is_comparison_example.R` to see how IS differs between a highly regular activity pattern and a noisy, irregular one.

```r
source("interdaily_stability.R")
source("is_comparison_example.R")
```

必要なら次に、そのまま GitHub に貼れるように
**「## Usage」以下だけの完成版 README 用テキスト** に整形します。
