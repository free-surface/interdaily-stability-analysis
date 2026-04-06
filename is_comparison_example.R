# =============================================================================
# is_comparison_example.R
#
# Demonstrates how Interdaily Stability (IS) differs between two simulated
# activity scenarios:
#
#   Case 1 – High IS: strong circadian amplitude, low noise
#             → activity pattern repeats consistently day to day
#
#   Case 2 – Low IS: weak circadian amplitude, high noise
#             → activity pattern is irregular and varies across days
#
# Dependencies: interdaily_stability.R  (must be sourced first)
# =============================================================================

# source("interdaily_stability.R")   # uncomment if not yet loaded


# -----------------------------------------------------------------------------
# Case 1: High Interdaily Stability
#
# Parameters chosen to produce a clear, stable 24-hour rhythm:
#   - Large amplitude (1.2) relative to noise SD (0.15)  → strong signal-to-noise
#   - Zero trend                                          → no long-term drift
# Expected outcome: IS close to 1 (highly regular pattern)
# -----------------------------------------------------------------------------
res1 <- check_IS_example(
  n_days    = 14,
  epoch     = "hour",
  baseline  = 1.5,   # mean MET level
  amplitude = 1.2,   # large oscillation around the baseline
  peak_hour = 14,    # activity peaks at 14:00
  noise_sd  = 0.15,  # low noise → clean circadian signal
  trend     = 0,     # no day-to-day drift
  seed      = 1
)


# -----------------------------------------------------------------------------
# Case 2: Low Interdaily Stability
#
# Parameters chosen to produce a weak, noisy rhythm:
#   - Small amplitude (0.3) relative to noise SD (0.8)   → poor signal-to-noise
#   - Noise dominates, so the day-to-day pattern varies substantially
# Expected outcome: IS close to 0 (irregular, unstable pattern)
# -----------------------------------------------------------------------------
res2 <- check_IS_example(
  n_days    = 14,
  epoch     = "hour",
  baseline  = 1.5,   # same mean level as Case 1 for a fair comparison
  amplitude = 0.3,   # small oscillation — rhythm is barely present
  peak_hour = 14,    # same peak hour (effect is weak due to low amplitude)
  noise_sd  = 0.8,   # high noise → obscures the circadian component
  trend     = 0,     # default; explicitly set for clarity
  seed      = 2      # different seed to get an independent realisation
)


# -----------------------------------------------------------------------------
# Side-by-side comparison
#
# Print the IS values from both runs together so the contrast is immediately
# visible, along with a brief plain-English interpretation of each.
# -----------------------------------------------------------------------------
cat("\n=============================================\n")
cat(" IS Comparison: Case 1 vs. Case 2\n")
cat("=============================================\n\n")

cat(sprintf(" Case 1 (high amplitude, low noise)  IS = %.4f\n", res1$result$IS))
cat(sprintf("   → %s\n\n", res1$message))

cat(sprintf(" Case 2 (low amplitude, high noise)  IS = %.4f\n", res2$result$IS))
cat(sprintf("   → %s\n\n", res2$message))

cat("=============================================\n")