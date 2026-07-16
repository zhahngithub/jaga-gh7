import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  const Report({
    required this.id,
    required this.creatorId,
    required this.category,
    required this.reportType,
    required this.severity,
    required this.description,
    required this.location,
    required this.geohash,
    required this.status,
    required this.upvoteCount,
    required this.downvoteCount,
    required this.confidenceScore,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String creatorId;
  final String category;
  final String reportType;
  final int severity;
  final String description;
  final GeoPoint location;
  final String geohash;
  final String status;
  final int upvoteCount;
  final int downvoteCount;
  final double confidenceScore;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Report.fromJson(Map<String, dynamic> json, {required String id}) {
    return Report(
      id: id,
      creatorId: json['creatorId'] as String,
      category: json['category'] as String,
      reportType: json['reportType'] as String,
      severity: (json['severity'] as num).toInt(),
      description: json['description'] as String,
      location: json['location'] as GeoPoint,
      geohash: json['geohash'] as String,
      status: json['status'] as String,
      upvoteCount: (json['upvoteCount'] as num?)?.toInt() ?? 0,
      downvoteCount: (json['downvoteCount'] as num?)?.toInt() ?? 0,
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.0,
      createdAt: _dateTimeFromJson(json['createdAt']),
      updatedAt: _dateTimeFromJson(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'creatorId': creatorId,
      'category': category,
      'reportType': reportType,
      'severity': severity,
      'description': description,
      'location': location,
      'geohash': geohash,
      'status': status,
      'upvoteCount': upvoteCount,
      'downvoteCount': downvoteCount,
      'confidenceScore': confidenceScore,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Report copyWith({String? id, String? geohash}) {
    return Report(
      id: id ?? this.id,
      creatorId: creatorId,
      category: category,
      reportType: reportType,
      severity: severity,
      description: description,
      location: location,
      geohash: geohash ?? this.geohash,
      status: status,
      upvoteCount: upvoteCount,
      downvoteCount: downvoteCount,
      confidenceScore: confidenceScore,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime _dateTimeFromJson(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.parse(value).toUtc();
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
