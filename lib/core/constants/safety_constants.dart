abstract final class SafetyConstants {
  // Off-route detection.
  static const double offRouteDistanceM = 50;
  static const int offRouteSustainedSeconds = 60;
  static const int gpsAccuracyRejectM = 25;

  // Escalation timings.
  static const int offRouteConfirmSeconds = 30;
  static const int communityFanoutDelaySeconds = 0;

  // Location cadence.
  static const int locationWriteIntervalSeconds = 15;
  static const double locationWriteDistanceM = 50;
  static const int alertLocationWriteIntervalSeconds = 5;
  static const double streamDistanceFilterM = 15;

  // Scoring.
  static const double sampleIntervalM = 25;
  static const double routeBufferM = 300;
  static const double wMean = 0.6;
  static const double wPeak = 0.4;
  static const double riskPercentile = 0.9;
  static const double riskScale = 30;
  static const double maxProtectiveOffset = 0.4;
  static const double evidenceSaturation = 8;
  static const double lowConfidenceUpperBound = 0.33;
  static const double mediumConfidenceUpperBound = 0.66;

  // Per-report influence.
  static const int minimumSeverity = 1;
  static const int maximumSeverity = 5;
  static const double confidenceBaseWeight = 0.4;
  static const double confidenceRangeWeight = 0.6;
  static const double sigmaSeverityBase = 0.6;
  static const double sigmaSeverityStep = 0.08;
  static const double spatialCullSigmaMultiplier = 3;
  static const double activeStateMultiplier = 1;
  static const double confirmedStateMultiplier = 1.25;
  static const double disputedStateMultiplier = 0.4;
  static const double inactiveStateMultiplier = 0;
  static const double maximumNormalizedRisk = 100;

  // Geo.
  static const double earthRadiusM = 6371008.8;
  static const double routePointEpsilonM = 0.01;
  static const int geohashPrecisionStored = 9;
  static const int geohashPrecisionQuery = 6;
  static const double mapQueryRadiusM = 1500;
  static const double helperNotifyRadiusM = 500;
  static const int helperLocationStaleHours = 2;

  // Map presentation.
  static const double reportDetailZoom = 16.5;

  // Report states.
  static const int confirmUpvotes = 3;
  static const int confirmNet = 3;
  static const int disputeDownvotes = 3;
  static const int disputeNet = -2;

  // Feature flags.
  static const bool enableDensityModifier = false;
}
