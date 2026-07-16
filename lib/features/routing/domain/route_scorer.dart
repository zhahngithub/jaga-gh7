import 'dart:math' as math;

import '../../../core/constants/safety_constants.dart';
import '../../../core/utils/geo_coordinate.dart';
import '../../../core/utils/geo_utils.dart';
import '../../reports/domain/models/report_category.dart';
import '../../reports/domain/models/safety_report.dart';
import '../../reports/domain/scoring/risk_field.dart';
import 'route_geometry_utils.dart';

enum RouteConfidence { low, medium, high }

class RouteScore {
  const RouteScore({
    required this.routeRisk,
    required this.safetyScore,
    required this.confidence,
    required this.sampledPointCount,
  });

  final double routeRisk;
  final int safetyScore;
  final RouteConfidence confidence;
  final int sampledPointCount;
}

RouteScore scoreRoute({
  required List<GeoCoordinate> route,
  required Iterable<SafetyReport> reports,
  required DateTime evaluatedAt,
}) {
  final nearbyReports = route.isEmpty
      ? <SafetyReport>[]
      : reports
            .where((report) {
              return safetyCategories.containsKey(report.categoryId) &&
                  reportContributesAt(report, evaluatedAt) &&
                  distanceToRouteMeters(report.location, route) <=
                      SafetyConstants.routeBufferM;
            })
            .toList(growable: false);
  final sampledPoints = resampleRoute(route);
  final risks = sampledPoints
      .map(
        (point) => riskAt(
          point: point,
          reports: nearbyReports,
          evaluatedAt: evaluatedAt,
        ),
      )
      .toList(growable: false);
  final routeRisk = aggregateRouteRisk(risks);

  return RouteScore(
    routeRisk: routeRisk,
    safetyScore: _safetyScoreFromRouteRisk(routeRisk),
    confidence: _routeConfidence(nearbyReports, evaluatedAt),
    sampledPointCount: sampledPoints.length,
  );
}

double aggregateRouteRisk(List<double> risks) {
  if (risks.isEmpty) {
    return 0;
  }
  if (risks.any((risk) => !risk.isFinite || risk < 0)) {
    throw ArgumentError.value(
      risks,
      'risks',
      'must contain only finite, non-negative values',
    );
  }

  final mean = risks.reduce((first, second) => first + second) / risks.length;
  final peak = _percentile(risks, SafetyConstants.riskPercentile);
  return SafetyConstants.wMean * mean + SafetyConstants.wPeak * peak;
}

int _safetyScoreFromRouteRisk(double routeRisk) {
  if (!routeRisk.isFinite) {
    return 0;
  }
  final boundedRisk = math.max(0, routeRisk);
  final normalizedRisk =
      SafetyConstants.maximumNormalizedRisk *
      (1 - math.exp(-boundedRisk / SafetyConstants.riskScale));
  final safetyScore = (SafetyConstants.maximumNormalizedRisk - normalizedRisk)
      .round();
  return safetyScore.clamp(0, SafetyConstants.maximumNormalizedRisk.toInt());
}

RouteConfidence _routeConfidence(
  Iterable<SafetyReport> reports,
  DateTime evaluatedAt,
) {
  var evidence = 0.0;
  for (final report in reports) {
    final category = safetyCategories[report.categoryId];
    if (category == null) {
      continue;
    }
    evidence +=
        (report.upvotes + report.downvotes + 1) *
        reportAgeDecay(report, category, evaluatedAt);
  }
  final confidence = math.min(1, evidence / SafetyConstants.evidenceSaturation);

  if (confidence < SafetyConstants.lowConfidenceUpperBound) {
    return RouteConfidence.low;
  }
  if (confidence < SafetyConstants.mediumConfidenceUpperBound) {
    return RouteConfidence.medium;
  }
  return RouteConfidence.high;
}

double _percentile(List<double> values, double percentile) {
  final sorted = List<double>.of(values)..sort();
  if (sorted.length == 1) {
    return sorted.single;
  }

  final position = (sorted.length - 1) * percentile;
  final lowerIndex = position.floor();
  final upperIndex = position.ceil();
  if (lowerIndex == upperIndex) {
    return sorted[lowerIndex];
  }
  final fraction = position - lowerIndex;
  return sorted[lowerIndex] +
      (sorted[upperIndex] - sorted[lowerIndex]) * fraction;
}
