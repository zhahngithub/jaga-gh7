import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jaga/core/config/safety_constants.dart';
import 'package:jaga/core/models/geo_coordinate.dart';
import 'package:jaga/core/models/report.dart';
import 'package:jaga/core/scoring/risk_field.dart';

void main() {
  final evaluatedAt = DateTime.utc(2026, 7, 16, 12);
  final origin = GeoCoordinate(latitude: -6.2, longitude: 106.8);

  SafetyReport report({
    String id = 'report-1',
    String categoryId = 'poor_lighting',
    int severity = 5,
    GeoCoordinate? location,
    DateTime? incidentAt,
    ReportStatus status = ReportStatus.active,
    int upvotes = 0,
    int downvotes = 0,
    DateTime? expiresAt,
  }) {
    return SafetyReport(
      id: id,
      categoryId: categoryId,
      severity: severity,
      location: location ?? origin,
      incidentAt: incidentAt ?? evaluatedAt,
      status: status,
      upvotes: upvotes,
      downvotes: downvotes,
      expiresAt: expiresAt,
    );
  }

  double risk(Iterable<SafetyReport> reports, {GeoCoordinate? point}) {
    return riskAt(
      point: point ?? origin,
      reports: reports,
      evaluatedAt: evaluatedAt,
    );
  }

  group('riskAt', () {
    test('no reports produce zero known risk', () {
      expect(risk(const []), 0);
    });

    test('hazard influence decreases with distance', () {
      final hazard = report();

      final atSource = risk([hazard]);
      final oneHundredMetersAway = risk([
        hazard,
      ], point: _pointNorthOf(origin, 100));

      expect(atSource, greaterThan(oneHundredMetersAway));
      expect(oneHundredMetersAway, greaterThan(0));
    });

    test('influence is zero outside the three-sigma spatial cull', () {
      final hazard = report();

      // Severity 5 gives poor_lighting its base sigma of 80 metres.
      final outsideCull = _pointNorthOf(
        origin,
        80 * SafetyConstants.spatialCullSigmaMultiplier + 1,
      );

      expect(risk([hazard], point: outsideCull), 0);
    });

    test('older reports contribute less than recent reports', () {
      final recent = report(id: 'recent', categoryId: 'suspicious_activity');
      final oneHalfLifeOld = report(
        id: 'old',
        categoryId: 'suspicious_activity',
        incidentAt: evaluatedAt.subtract(const Duration(hours: 72)),
      );

      expect(risk([oneHalfLifeOld]), closeTo(risk([recent]) / 2, 1e-12));
    });

    test('upvotes increase effective influence', () {
      final fresh = report(id: 'fresh');
      final supported = report(id: 'supported', upvotes: 10);

      expect(risk([supported]), greaterThan(risk([fresh])));
    });

    test('disputed reports contribute less than active reports', () {
      final active = report(id: 'active');
      final disputed = report(id: 'disputed', status: ReportStatus.disputed);

      expect(risk([disputed]), closeTo(risk([active]) * 0.4, 1e-12));
    });

    test('resolved and expired reports contribute zero', () {
      final reports = [
        report(id: 'resolved', status: ReportStatus.resolved),
        report(id: 'expired-status', status: ReportStatus.expired),
        report(
          id: 'expired-time',
          expiresAt: evaluatedAt.subtract(const Duration(seconds: 1)),
        ),
      ];

      expect(risk(reports), 0);
    });

    test('protective influence never offsets more than the configured cap', () {
      final hazard = report(id: 'hazard', categoryId: 'robbery');
      final hazardOnlyRisk = risk([hazard]);
      final protectiveReports = List.generate(
        10,
        (index) => report(id: 'police-$index', categoryId: 'police_station'),
      );

      expect(
        risk([hazard, ...protectiveReports]),
        closeTo(
          hazardOnlyRisk * (1 - SafetyConstants.maxProtectiveOffset),
          1e-12,
        ),
      );
    });

    test('protective evidence alone does not create negative risk', () {
      final protective = report(categoryId: 'police_station');

      expect(risk([protective]), 0);
    });

    test('unknown categories are safely ignored', () {
      expect(risk([report(categoryId: 'unknown')]), 0);
    });

    test('future incident times are treated as age zero', () {
      final current = report(id: 'current');
      final future = report(
        id: 'future',
        incidentAt: evaluatedAt.add(const Duration(hours: 1)),
      );

      expect(risk([future]), closeTo(risk([current]), 1e-12));
    });
  });

  group('SafetyReport validation', () {
    test('rejects invalid severity and vote counts', () {
      expect(() => report(severity: 0), throwsRangeError);
      expect(() => report(upvotes: -1), throwsRangeError);
      expect(() => report(downvotes: -1), throwsRangeError);
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
