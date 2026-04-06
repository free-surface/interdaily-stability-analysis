# =============================================================================
# interdaily_stability.R
#
# Utilities for computing and visualising Interdaily Stability (IS), a metric
# that quantifies how consistently a 24-hour activity pattern repeats across
# days.
#
# IS ranges from 0 to 1:
#   1  – identical pattern every day (perfect stability)
#   0  – activity is distributed as if drawn from white noise (no regularity)
#
# Formula (Van Someren et al., 1999):
#   IS = [ N * Σ_h (x̄_h − x̄)² ] / [ p * Σ_i (x_i − x̄)² ]
#
#   N   – total number of epochs
#   p   – number of epochs per day (24 for hourly, 1440 for minute-level)
#   x̄_h – mean value at epoch-of-day h, averaged across all days
#   x̄   – grand mean over all epochs
#   x_i – value of the i-th epoch
#
# Functions
#   generate_activity_data()      Simulate circadian activity (METs) data
#   aggregate_activity()          Bin raw data to hourly or minute epochs
#   calc_IS()                     Compute IS
#   get_daily_profile()           Compute the mean 24-hour activity profile
#   plot_activity_timeseries()    ggplot2 time-series plot
#   plot_daily_profile()          ggplot2 mean daily profile plot
#   describe_IS()                 Return a plain-English interpretation of IS
#   check_IS_example()            End-to-end demo: simulate → compute → plot
#
# Dependencies: dplyr, lubridate, ggplot2, patchwork
# =============================================================================


# -----------------------------------------------------------------------------
# Package management
# Install any missing packages, then load all required libraries.
# -----------------------------------------------------------------------------
required_pkgs <- c("dplyr", "lubridate", "ggplot2", "patchwork")

new_pkgs <- required_pkgs[!(required_pkgs %in% installed.packages()[, "Package"])]
if (length(new_pkgs) > 0) {
  install.packages(new_pkgs, repos = "https://cloud.r-project.org")
}

invisible(lapply(required_pkgs, library, character.only = TRUE))


# -----------------------------------------------------------------------------
# generate_activity_data
#
# Simulate a multi-day physical activity time series with an embedded
# circadian (24-hour) rhythm.
#
# The signal model is:
#   METs(t) = baseline + amplitude * cos(2π(t_hour − peak_hour) / 24)
#           + trend * day_index + N(0, noise_sd²)
#
# Values below zero are clipped to zero (activity cannot be negative).
#
# Arguments:
#   n_days     Number of days to simulate                     (default 14)
#   epoch      Time resolution: "hour" (1-h epochs) or
#              "minute" (1-min epochs)                        (default "hour")
#   baseline   Mean activity level (METs)                     (default 1.5)
#   amplitude  Peak-to-MESOR amplitude of the cosine signal   (default 1.0)
#   peak_hour  Hour of day at which activity is maximal (0–23)(default 14)
#   noise_sd   SD of additive Gaussian noise                  (default 0.2)
#   trend      Linear trend per day (slope); 0 = no trend     (default 0)
#   seed       Random seed for reproducibility                (default 1)
#
# Returns:
#   A data.frame with columns:
#     time – POSIXct timestamps (Asia/Tokyo timezone)
#     METs – simulated activity values (METs ≥ 0)
# -----------------------------------------------------------------------------
generate_activity_data <- function(
    n_days     = 14,
    epoch      = c("hour", "minute"),
    baseline   = 1.5,
    amplitude  = 1.0,
    peak_hour  = 14,
    noise_sd   = 0.2,
    trend      = 0,
    seed       = 1
) {
  epoch <- match.arg(epoch)
  set.seed(seed)

  # Determine the sampling interval and number of epochs per day.
  by_str    <- if (epoch == "hour") "1 hour" else "1 min"
  n_per_day <- if (epoch == "hour") 24L else 24L * 60L

  # Build the complete timestamp sequence.
  time_seq <- seq(
    from       = as.POSIXct("2026-01-01 00:00:00", tz = "Asia/Tokyo"),
    by         = by_str,
    length.out = n_days * n_per_day
  )

  # Fractional hour-of-day (0 to <24) used for the cosine phase calculation.
  t_hour <- lubridate::hour(time_seq) + lubridate::minute(time_seq) / 60

  # Circadian component: cosine centred on peak_hour.
  circadian_signal <- amplitude * cos(2 * pi * (t_hour - peak_hour) / 24)

  # Optional slow linear trend across days (day 0 = first day).
  day_index   <- as.numeric(as.Date(time_seq) - min(as.Date(time_seq)))
  slow_change <- trend * day_index

  # Combine components and add noise; clip negative values to 0.
  METs        <- baseline + circadian_signal + slow_change +
                 rnorm(length(time_seq), sd = noise_sd)
  METs[METs < 0] <- 0

  data.frame(time = time_seq, METs = METs)
}


# -----------------------------------------------------------------------------
# aggregate_activity
#
# Aggregate a fine-grained activity data.frame to a regular epoch grid
# (hourly or per-minute) by averaging within each epoch.
#
# This is useful as a preprocessing step before IS calculation when the
# raw data have a higher or irregular sampling rate.
#
# Arguments:
#   df         data.frame with at least columns "time" (POSIXct) and
#              value_col
#   value_col  Name of the activity column to aggregate    (default "METs")
#   epoch      Target resolution: "hour" or "minute"       (default "hour")
#
# Returns:
#   A data.frame with columns "time" (floored to the target epoch) and
#   value_col (mean within each epoch).
# -----------------------------------------------------------------------------
aggregate_activity <- function(df,
                               value_col = "METs",
                               epoch     = c("hour", "minute")) {
  epoch <- match.arg(epoch)

  stopifnot("time"      %in% names(df))
  stopifnot(value_col   %in% names(df))

  unit_name <- if (epoch == "hour") "hour" else "minute"

  df_out <- df %>%
    dplyr::mutate(time_epoch = lubridate::floor_date(time, unit = unit_name)) %>%
    dplyr::group_by(time_epoch) %>%
    dplyr::summarise(
      value  = mean(.data[[value_col]], na.rm = TRUE),
      .groups = "drop"
    )

  # Restore the original column names so the output is easy to chain.
  names(df_out)[names(df_out) == "time_epoch"] <- "time"
  names(df_out)[names(df_out) == "value"]      <- value_col

  df_out
}


# -----------------------------------------------------------------------------
# calc_IS
#
# Compute the Interdaily Stability (IS) index.
#
# IS measures the similarity of the 24-hour activity pattern across days.
# Internally the function:
#   1. Aggregates the data to the requested epoch length.
#   2. Computes the mean value for each epoch-of-day (x̄_h).
#   3. Applies the IS formula.
#
# Arguments:
#   df         data.frame with columns "time" (POSIXct) and value_col
#   value_col  Name of the activity column                 (default "METs")
#   epoch      Epoch length: "hour" or "minute"            (default "hour")
#
# Returns:
#   A named list with:
#     IS           – the IS value (numeric scalar, 0 to 1)
#     N            – total number of epochs in the data
#     p            – number of epochs per day
#     mean_overall – grand mean (x̄)
#     profile      – data.frame of per-epoch-of-day means (x̄_h)
#     data_used    – aggregated data.frame used for the calculation
# -----------------------------------------------------------------------------
calc_IS <- function(df,
                    value_col = "METs",
                    epoch     = c("hour", "minute")) {
  epoch <- match.arg(epoch)

  stopifnot("time"    %in% names(df))
  stopifnot(value_col %in% names(df))

  # Aggregate to the target epoch resolution.
  df_use <- aggregate_activity(df, value_col = value_col, epoch = epoch)

  if (any(is.na(df_use[[value_col]]))) {
    stop(paste(
      "Missing values (NA) detected in", value_col,
      "after aggregation. Please impute or remove them before calling calc_IS()."
    ))
  }

  # Assign an epoch-of-day index (0-based):
  #   hourly  → 0..23
  #   minute  → 0..1439
  if (epoch == "hour") {
    p      <- 24L
    df_use <- df_use %>%
      dplyr::mutate(epoch_index = lubridate::hour(time))
  } else {
    p      <- 24L * 60L
    df_use <- df_use %>%
      dplyr::mutate(
        epoch_index = lubridate::hour(time) * 60L + lubridate::minute(time)
      )
  }

  N     <- nrow(df_use)
  x_bar <- mean(df_use[[value_col]])   # grand mean

  # Mean activity for each epoch-of-day (x̄_h), averaged across all days.
  x_h <- df_use %>%
    dplyr::group_by(epoch_index) %>%
    dplyr::summarise(mean_xh = mean(.data[[value_col]]), .groups = "drop") %>%
    dplyr::arrange(epoch_index)

  # IS formula:
  #   numerator   = N * Σ_h (x̄_h − x̄)²   (between-epoch-of-day variance scaled by N)
  #   denominator = p * Σ_i (x_i − x̄)²   (total variance scaled by p)
  numerator   <- N * sum((x_h$mean_xh - x_bar)^2)
  denominator <- p * sum((df_use[[value_col]] - x_bar)^2)

  IS <- numerator / denominator

  list(
    IS           = IS,
    N            = N,
    p            = p,
    mean_overall = x_bar,
    profile      = x_h,
    data_used    = df_use
  )
}


# -----------------------------------------------------------------------------
# get_daily_profile
#
# Compute the mean 24-hour activity profile by averaging each epoch-of-day
# across all available days.
#
# Arguments:
#   df         data.frame with columns "time" and value_col
#   value_col  Name of the activity column                 (default "METs")
#   epoch      Epoch length: "hour" or "minute"            (default "hour")
#
# Returns:
#   A data.frame with columns:
#     epoch_index – epoch-of-day index (0-based)
#     mean_value  – mean activity at that epoch of day
# -----------------------------------------------------------------------------
get_daily_profile <- function(df,
                              value_col = "METs",
                              epoch     = c("hour", "minute")) {
  epoch  <- match.arg(epoch)
  df_use <- aggregate_activity(df, value_col = value_col, epoch = epoch)

  if (epoch == "hour") {
    df_profile <- df_use %>%
      dplyr::mutate(epoch_index = lubridate::hour(time))
  } else {
    df_profile <- df_use %>%
      dplyr::mutate(
        epoch_index = lubridate::hour(time) * 60L + lubridate::minute(time)
      )
  }

  df_profile %>%
    dplyr::group_by(epoch_index) %>%
    dplyr::summarise(mean_value = mean(.data[[value_col]]), .groups = "drop") %>%
    dplyr::arrange(epoch_index)
}


# -----------------------------------------------------------------------------
# plot_activity_timeseries
#
# Plot the full raw (or aggregated) activity time series as a line plot.
#
# Arguments:
#   df         data.frame with columns "time" (POSIXct) and value_col
#   value_col  Name of the activity column to plot         (default "METs")
#
# Returns:
#   A ggplot object.
# -----------------------------------------------------------------------------
plot_activity_timeseries <- function(df, value_col = "METs") {
  ggplot(df, aes(x = time, y = .data[[value_col]])) +
    geom_line(colour = "steelblue", linewidth = 0.4) +
    labs(
      x     = "Time",
      y     = value_col,
      title = "Activity Time Series"
    ) +
    theme_bw()
}


# -----------------------------------------------------------------------------
# plot_daily_profile
#
# Plot the mean 24-hour activity profile (epoch-of-day on the x-axis,
# mean activity on the y-axis).
#
# Arguments:
#   df         data.frame with columns "time" and value_col
#   value_col  Name of the activity column                 (default "METs")
#   epoch      Epoch length: "hour" or "minute"            (default "hour")
#
# Returns:
#   A ggplot object.
# -----------------------------------------------------------------------------
plot_daily_profile <- function(df,
                               value_col = "METs",
                               epoch     = c("hour", "minute")) {
  epoch    <- match.arg(epoch)
  prof     <- get_daily_profile(df, value_col = value_col, epoch = epoch)
  xlab_str <- if (epoch == "hour") "Hour of day" else "Minute of day"

  ggplot(prof, aes(x = epoch_index, y = mean_value)) +
    geom_line(colour = "steelblue", linewidth = 0.7) +
    geom_point(size = 1.5) +
    labs(
      x     = xlab_str,
      y     = paste0("Mean ", value_col),
      title = "Average 24-Hour Activity Profile"
    ) +
    theme_bw()
}


# -----------------------------------------------------------------------------
# describe_IS
#
# Return a plain-English interpretation of an IS value.
#
# Thresholds (heuristic, based on published actigraphy literature):
#   IS ≥ 0.6  → high stability
#   IS ≥ 0.3  → moderate stability
#   IS < 0.3  → low stability
#
# Arguments:
#   IS_value  Numeric scalar returned by calc_IS()$IS
#
# Returns:
#   A single character string describing what the IS value implies.
# -----------------------------------------------------------------------------
describe_IS <- function(IS_value) {
  if (!is.finite(IS_value)) {
    return(paste(
      "IS could not be computed. Check that the data span at least two days",
      "and that the activity values have non-zero variance."
    ))
  }

  if (IS_value >= 0.6) {
    return(paste(
      "IS is relatively high, indicating that the day-to-day activity pattern",
      "is highly consistent and the circadian rhythm is stable."
    ))
  } else if (IS_value >= 0.3) {
    return(paste(
      "IS is moderate, suggesting a discernible 24-hour rhythm but with",
      "noticeable day-to-day variability in the activity pattern."
    ))
  } else {
    return(paste(
      "IS is low, indicating that the day-to-day activity pattern is irregular",
      "and the circadian rhythm is relatively unstable."
    ))
  }
}


# -----------------------------------------------------------------------------
# check_IS_example
#
# End-to-end demonstration:
#   1. Simulate activity data with the specified parameters.
#   2. Compute IS.
#   3. Print a formatted summary to the console.
#   4. Display a two-panel plot (time series on top, daily profile below).
#
# Arguments: (identical to generate_activity_data — see that function)
#
# Returns:
#   Invisibly, a list with:
#     data    – the simulated data.frame
#     result  – the list returned by calc_IS()
#     message – the plain-English IS interpretation string
# -----------------------------------------------------------------------------
check_IS_example <- function(
    n_days    = 14,
    epoch     = c("hour", "minute"),
    baseline  = 1.5,
    amplitude = 1.0,
    peak_hour = 14,
    noise_sd  = 0.2,
    trend     = 0,
    seed      = 1
) {
  epoch <- match.arg(epoch)

  # -- Simulate --
  df <- generate_activity_data(
    n_days    = n_days,
    epoch     = epoch,
    baseline  = baseline,
    amplitude = amplitude,
    peak_hour = peak_hour,
    noise_sd  = noise_sd,
    trend     = trend,
    seed      = seed
  )

  # -- Compute IS --
  res <- calc_IS(df, value_col = "METs", epoch = epoch)

  # -- Console summary --
  cat("=============================================\n")
  cat(" Interdaily Stability (IS) — Results\n")
  cat("=============================================\n\n")

  cat(sprintf(" IS = %.4f\n\n", res$IS))

  cat("[What is IS?]\n")
  cat(" IS measures how similar the 24-hour activity pattern is from day to\n")
  cat(" day. Higher values indicate a more stable, regular circadian rhythm;\n")
  cat(" lower values indicate an irregular, unpredictable pattern.\n\n")

  cat("[Interpretation of this result]\n")
  cat("", describe_IS(res$IS), "\n")
  cat("\n=============================================\n")

  # -- Plots (stacked vertically with patchwork) --
  p1 <- plot_activity_timeseries(df, value_col = "METs")
  p2 <- plot_daily_profile(df, value_col = "METs", epoch = epoch)

  print(p1 / p2)   # patchwork "/" operator: p1 on top, p2 below

  invisible(list(
    data    = df,
    result  = res,
    message = describe_IS(res$IS)
  ))
}
