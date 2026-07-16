import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jaga/core/config/safety_constants.dart';
import 'package:jaga/core/models/geo_coordinate.dart';
import 'package:jaga/core/models/report.dart';
import 'package:jaga/core/scoring/risk_field.dart';
import 'package:jaga/core/scoring/route_geometry_utils.dart';
import 'package:jaga/core/scoring/route_scorer.dart';

void main() {
  final evaluatedAt = DateTime.utc(2026, 7, 16, 12);
  final origin = GeoCoordinate(latitude: -6.2, longitude: 106.8);
  final destination = _pointNorthOf(origin, 100);

  SafetyReport report({
    required String id,
    GeoCoordinate? location,
    String categoryId = 'robbery',
    int upvotes = 0,
    int downvotes = 0,
  }) {
    return SafetyReport(
      id: id,
      categoryId: categoryId,
      severity: 5,
      location: location ?? origin,
      incidentAt: evaluatedAt,
      status: ReportStatus.active,
      upvotes: upvotes,
      downvotes: downvotes,
    );
  }

  test('route risk blends average risk with high-risk segments', () {
    final risks = <double>[0, 0, 0, 0, 0, 0, 0, 0, 10, 10];

    final routeRisk = aggregateRouteRisk(risks);

    expect(routeRisk, closeTo(5.2, 1e-12));
    expect(routeRisk, greaterThan(2));
  });

  test(
    'empty route and evidence produce arithmetic 100 with low confidence',
    () {
      final result = scoreRoute(
        route: const [],
        reports: const [],
        evaluatedAt: evaluatedAt,
      );

      expect(result.routeRisk, 0);
      expect(result.safetyScore, 100);
      expect(result.confidence, RouteConfidence.low);
      expect(result.sampledPointCount, 0);
    },
  );

  test('no evidence on a valid route remains explicitly low confidence', () {
    final result = scoreRoute(
      route: [origin, destination],
      reports: const [],
      evaluatedAt: evaluatedAt,
    );

    expect(result.safetyScore, 100);
    expect(result.confidence, RouteConfidence.low);
  });

  test('scoreRoute uses riskAt and performs the safety inversion once', () {
    final hazard = report(id: 'hazard');
    final knownRisk = riskAt(
      point: origin,
      reports: [hazard],
      evaluatedAt: evaluatedAt,
    );
    final result = scoreRoute(
      route: [origin],
      reports: [hazard],
      evaluatedAt: evaluatedAt,
    );
    final normalizedRisk =
        SafetyConstants.maximumNormalizedRisk *
        (1 - math.exp(-knownRisk / SafetyConstants.riskScale));
    final expectedSafetyScore =
        (SafetyConstants.maximumNormalizedRisk - normalizedRisk).round();

    expect(result.routeRisk, closeTo(knownRisk, 1e-12));
    expect(result.safetyScore, expectedSafetyScore);
    expect(result.safetyScore, lessThan(100));
  });

  test('evidence confidence is independent from the safety score', () {
    final evidence = List.generate(8, (index) => report(id: 'report-$index'));

    final result = scoreRoute(
      route: [origin, destination],
      reports: evidence,
      evaluatedAt: evaluatedAt,
    );

    expect(result.confidence, RouteConfidence.high);
    expect(result.safetyScore, lessThan(100));
  });

  test('reports outside the corridor affect neither risk nor confidence', () {
    final farReport = report(
      id: 'far',
      location: _pointNorthOf(origin, SafetyConstants.routeBufferM + 100),
    );

    final result = scoreRoute(
      route: [origin, destination],
      reports: [farReport],
      evaluatedAt: evaluatedAt,
    );

    expect(result.routeRisk, 0);
    expect(result.safetyScore, 100);
    expect(result.confidence, RouteConfidence.low);
  });

  test('aggregateRouteRisk rejects invalid values', () {
    expect(() => aggregateRouteRisk([-1]), throwsArgumentError);
    expect(() => aggregateRouteRisk([double.nan]), throwsArgumentError);
  });

  group('route geometry', () {
    test('resampling preserves endpoints and respects the sample interval', () {
      final samples = resampleRoute([origin, destination]);

      expect(samples.first, origin);
      expect(samples.last, destination);
      expect(samples, hasLength(5));
    });

    test('GeoJSON converts longitude-latitude into domain coordinates', () {
      final points = geoJsonLineStringPoints({
        'type': 'LineString',
        'coordinates': [
          [106.8, -6.2],
          [106.81, -6.21],
        ],
      });

      expect(points.first.latitude, -6.2);
      expect(points.first.longitude, 106.8);
      expect(points.last.latitude, -6.21);
      expect(points.last.longitude, 106.81);
    });

    test('invalid route inputs fail clearly', () {
      expect(
        () => resampleRoute([origin, destination], intervalMeters: 0),
        throwsArgumentError,
      );
      expect(
        () => geoJsonLineStringPoints({
          'type': 'Point',
          'coordinates': [106.8, -6.2],
        }),
        throwsFormatException,
      );
      expect(
        () => geoJsonLineStringPoints({
          'type': 'LineString',
          'coordinates': [
            [200, -6.2],
          ],
        }),
        throwsFormatException,
      );
    });
  });
}

GeoCoordinate _pointNorthOf(GeoCoordinate point, double meters) {
  final latitudeDelta = meters / SafetyConstants.earthRadiusM * 180 / math.pi;
  return GeoCoordinate(
    latitude: point.latitude + latitudeDelta,
    longitude: point.longitude,
  );
}
