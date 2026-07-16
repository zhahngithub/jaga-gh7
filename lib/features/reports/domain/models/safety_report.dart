import '../../../../core/constants/safety_constants.dart';
import '../../../../core/utils/geo_coordinate.dart';

enum ReportStatus { active, confirmed, disputed, resolved, expired }

class SafetyReport {
  SafetyReport({
    required this.id,
    required this.categoryId,
    required this.severity,
    required this.location,
    required this.incidentAt,
    required this.status,
    this.upvotes = 0,
    this.downvotes = 0,
    this.expiresAt,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (categoryId.isEmpty) {
      throw ArgumentError.value(categoryId, 'categoryId', 'must not be empty');
    }
    if (severity < SafetyConstants.minimumSeverity ||
        severity > SafetyConstants.maximumSeverity) {
      throw RangeError.range(
        severity,
        SafetyConstants.minimumSeverity,
        SafetyConstants.maximumSeverity,
        'severity',
      );
    }
    if (upvotes < 0) {
      throw RangeError.value(upvotes, 'upvotes', 'must not be negative');
    }
    if (downvotes < 0) {
      throw RangeError.value(downvotes, 'downvotes', 'must not be negative');
    }
  }

  final String id;
  final String categoryId;
  final int severity;
  final GeoCoordinate location;
  final DateTime incidentAt;
  final ReportStatus status;
  final int upvotes;
  final int downvotes;
  final DateTime? expiresAt;
}
