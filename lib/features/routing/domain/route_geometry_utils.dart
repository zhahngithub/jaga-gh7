import '../../../core/constants/safety_constants.dart';
import '../../../core/utils/geo_coordinate.dart';
import '../../../core/utils/geo_utils.dart';

List<GeoCoordinate> resampleRoute(
  List<GeoCoordinate> route, {
  double intervalMeters = SafetyConstants.sampleIntervalM,
}) {
  if (!intervalMeters.isFinite || intervalMeters <= 0) {
    throw ArgumentError.value(
      intervalMeters,
      'intervalMeters',
      'must be finite and greater than zero',
    );
  }
  if (route.length < 2) {
    return List<GeoCoordinate>.of(route);
  }

  final samples = <GeoCoordinate>[route.first];
  var distanceUntilNextSample = intervalMeters;

  for (var index = 1; index < route.length; index++) {
    var segmentStart = route[index - 1];
    final segmentEnd = route[index];
    var segmentLength = distanceMeters(segmentStart, segmentEnd);

    while (segmentLength >= distanceUntilNextSample && segmentLength > 0) {
      final sample = interpolateCoordinate(
        segmentStart,
        segmentEnd,
        distanceUntilNextSample / segmentLength,
      );
      samples.add(sample);
      segmentStart = sample;
      segmentLength = distanceMeters(segmentStart, segmentEnd);
      distanceUntilNextSample = intervalMeters;
    }

    distanceUntilNextSample -= segmentLength;
  }

  if (distanceMeters(samples.last, route.last) >
      SafetyConstants.routePointEpsilonM) {
    samples.add(route.last);
  }
  return samples;
}

List<GeoCoordinate> geoJsonLineStringPoints(Map<String, Object?> geometry) {
  if (geometry['type'] != 'LineString') {
    throw const FormatException('GeoJSON geometry must be a LineString.');
  }
  final coordinates = geometry['coordinates'];
  if (coordinates is! List) {
    throw const FormatException('LineString coordinates must be a list.');
  }

  return coordinates
      .map((coordinate) {
        if (coordinate is! List || coordinate.length < 2) {
          throw const FormatException(
            'Each LineString coordinate must contain longitude and latitude.',
          );
        }
        final longitude = coordinate[0];
        final latitude = coordinate[1];
        if (longitude is! num || latitude is! num) {
          throw const FormatException(
            'LineString coordinates must be numeric.',
          );
        }
        try {
          return GeoCoordinate(
            latitude: latitude.toDouble(),
            longitude: longitude.toDouble(),
          );
        } on RangeError catch (error) {
          throw FormatException('Invalid LineString coordinate: $error');
        }
      })
      .toList(growable: false);
}
