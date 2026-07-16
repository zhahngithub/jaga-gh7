import 'dart:math' as math;

import '../constants/safety_constants.dart';
import 'geo_coordinate.dart';

double distanceMeters(GeoCoordinate first, GeoCoordinate second) {
  final latitudeDelta = _toRadians(second.latitude - first.latitude);
  final longitudeDelta = _toRadians(second.longitude - first.longitude);
  final firstLatitude = _toRadians(first.latitude);
  final secondLatitude = _toRadians(second.latitude);

  final haversine =
      math.pow(math.sin(latitudeDelta / 2), 2) +
      math.cos(firstLatitude) *
          math.cos(secondLatitude) *
          math.pow(math.sin(longitudeDelta / 2), 2);
  final clampedHaversine = haversine.clamp(0, 1).toDouble();
  final angularDistance = 2 * math.asin(math.sqrt(clampedHaversine));
  return SafetyConstants.earthRadiusM * angularDistance;
}

GeoCoordinate interpolateCoordinate(
  GeoCoordinate start,
  GeoCoordinate end,
  double fraction,
) {
  if (!fraction.isFinite) {
    throw ArgumentError.value(fraction, 'fraction', 'must be finite');
  }
  final boundedFraction = fraction.clamp(0, 1).toDouble();
  return GeoCoordinate(
    latitude:
        start.latitude + (end.latitude - start.latitude) * boundedFraction,
    longitude:
        start.longitude + (end.longitude - start.longitude) * boundedFraction,
  );
}

double distanceToRouteMeters(GeoCoordinate point, List<GeoCoordinate> route) {
  if (route.isEmpty) {
    return double.infinity;
  }
  if (route.length == 1) {
    return distanceMeters(point, route.first);
  }

  var closestDistance = double.infinity;
  for (var index = 1; index < route.length; index++) {
    final distance = _distanceToSegmentMeters(
      point,
      route[index - 1],
      route[index],
    );
    if (distance < closestDistance) {
      closestDistance = distance;
    }
  }
  return closestDistance;
}

double _distanceToSegmentMeters(
  GeoCoordinate point,
  GeoCoordinate start,
  GeoCoordinate end,
) {
  final referenceLatitude = _toRadians(
    (point.latitude + start.latitude + end.latitude) / 3,
  );

  final pointX =
      _wrappedLongitudeRadians(point.longitude - start.longitude) *
      math.cos(referenceLatitude) *
      SafetyConstants.earthRadiusM;
  final pointY =
      _toRadians(point.latitude - start.latitude) *
      SafetyConstants.earthRadiusM;
  final endX =
      _wrappedLongitudeRadians(end.longitude - start.longitude) *
      math.cos(referenceLatitude) *
      SafetyConstants.earthRadiusM;
  final endY =
      _toRadians(end.latitude - start.latitude) * SafetyConstants.earthRadiusM;

  final segmentLengthSquared = endX * endX + endY * endY;
  if (segmentLengthSquared == 0) {
    return distanceMeters(point, start);
  }

  final projection = ((pointX * endX + pointY * endY) / segmentLengthSquared)
      .clamp(0, 1)
      .toDouble();
  final deltaX = pointX - projection * endX;
  final deltaY = pointY - projection * endY;
  return math.sqrt(deltaX * deltaX + deltaY * deltaY);
}

double _toRadians(double degrees) => degrees * math.pi / 180;

double _wrappedLongitudeRadians(double degrees) {
  var radians = _toRadians(degrees);
  while (radians > math.pi) {
    radians -= 2 * math.pi;
  }
  while (radians < -math.pi) {
    radians += 2 * math.pi;
  }
  return radians;
}
