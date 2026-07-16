import 'dart:math' as math;

import '../config/categories.dart';
import '../config/safety_constants.dart';
import '../models/geo_coordinate.dart';
import '../models/report.dart';
import 'geo_utils.dart';

double riskAt({
  required GeoCoordinate point,
  required Iterable<SafetyReport> reports,
  required DateTime evaluatedAt,
}) {
  var hazard = 0.0;
  var protective = 0.0;

  for (final report in reports) {
    final category = safetyCategories[report.categoryId];
    if (category == null || !reportContributesAt(report, evaluatedAt)) {
      continue;
    }

    final influence = reportInfluenceAt(
      report: report,
      category: category,
      point: point,
      evaluatedAt: evaluatedAt,
    );
    switch (category.polarity) {
      case ReportPolarity.hazard:
        hazard += influence;
      case ReportPolarity.protective:
        protective += influence;
    }
  }

  final protectiveLimit = hazard * SafetyConstants.maxProtectiveOffset;
  final boundedProtective = math.min(protective, protectiveLimit);
  return math.max(0, hazard - boundedProtective);
}

double reportInfluenceAt({
  required SafetyReport report,
  required SafetyCategory category,
  required GeoCoordinate point,
  required DateTime evaluatedAt,
}) {
  if (!reportContributesAt(report, evaluatedAt)) {
    return 0;
  }

  final sigma =
      category.sigmaMeters *
      (SafetyConstants.sigmaSeverityBase +
          SafetyConstants.sigmaSeverityStep * report.severity);
  final distance = distanceMeters(report.location, point);
  if (distance > sigma * SafetyConstants.spatialCullSigmaMultiplier) {
    return 0;
  }

  final spatialFalloff = math.exp(-(distance * distance) / (2 * sigma * sigma));
  return reportWeight(report, category, evaluatedAt) * spatialFalloff;
}

double reportWeight(
  SafetyReport report,
  SafetyCategory category,
  DateTime evaluatedAt,
) {
  if (!reportContributesAt(report, evaluatedAt)) {
    return 0;
  }

  final severityWeight = report.severity / SafetyConstants.maximumSeverity;
  final confidence =
      (report.upvotes + 1) / (report.upvotes + report.downvotes + 2);
  final confidenceWeight =
      SafetyConstants.confidenceBaseWeight +
      SafetyConstants.confidenceRangeWeight * confidence;

  return severityWeight *
      reportAgeDecay(report, category, evaluatedAt) *
      confidenceWeight *
      _stateMultiplier(report.status);
}

double reportAgeDecay(
  SafetyReport report,
  SafetyCategory category,
  DateTime evaluatedAt,
) {
  final ageMicroseconds = evaluatedAt
      .difference(report.incidentAt)
      .inMicroseconds;
  final ageHours = math.max(0, ageMicroseconds / Duration.microsecondsPerHour);
  return math.exp(-math.ln2 * ageHours / category.halfLifeHours);
}

bool reportContributesAt(SafetyReport report, DateTime evaluatedAt) {
  if (report.expiresAt case final expiresAt?) {
    if (!expiresAt.isAfter(evaluatedAt)) {
      return false;
    }
  }
  return switch (report.status) {
    ReportStatus.active ||
    ReportStatus.confirmed ||
    ReportStatus.disputed => true,
    ReportStatus.resolved || ReportStatus.expired => false,
  };
}

double _stateMultiplier(ReportStatus status) => switch (status) {
  ReportStatus.active => SafetyConstants.activeStateMultiplier,
  ReportStatus.confirmed => SafetyConstants.confirmedStateMultiplier,
  ReportStatus.disputed => SafetyConstants.disputedStateMultiplier,
  ReportStatus.resolved ||
  ReportStatus.expired => SafetyConstants.inactiveStateMultiplier,
};
