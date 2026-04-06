# interdaily-stability-analysis
R utilities for computing and visualizing Interdaily Stability (IS), a metric of how consistently 24-hour activity patterns repeat across days. Includes simulation, aggregation, IS calculation, and plotting functions, with examples showing differences under varying signal-to-noise conditions. Suitable for actigraphy and circadian rhythm analysis.

## Usage

This repository provides R functions to compute and visualize **Interdaily Stability (IS)**, a measure of how consistently 24-hour activity patterns repeat across days.

### 1. Load functions

```r
source("interdaily_stability.R")
```

Main functions include data simulation, aggregation, IS calculation, plotting, and interpretation. Required packages are installed automatically.

### 2. Simulate data

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

Returns a data frame with `time` and `METs`.


### 3. Aggregate (optional)

```r
df_hourly <- aggregate_activity(df, value_col = "METs", epoch = "hour")
```


### 4. Compute IS

```r
res <- calc_IS(df, value_col = "METs", epoch = "hour")
res$IS
```

Output includes IS, summary statistics, and daily profile.


### 5. Daily profile

```r
profile <- get_daily_profile(df, value_col = "METs", epoch = "hour")
```

### 6. Plot

```r
plot_activity_timeseries(df)
plot_daily_profile(df, epoch = "hour")
```

### 7. Full example

```r
check_IS_example()
```

Runs simulation, IS calculation, and plots.


### 8. Comparison example

```r
source("interdaily_stability.R")
source("is_comparison_example.R")
```

Compares high-IS (strong rhythm, low noise) and low-IS (weak rhythm, high noise) cases.


