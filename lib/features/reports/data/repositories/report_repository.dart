import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_geohash/dart_geohash.dart';

import '../models/report.dart';

class ReportRepository {
  ReportRepository(this._firestore);

  final FirebaseFirestore _firestore;
  final GeoHasher _geoHasher = GeoHasher();

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('reports');

  Future<Report> addReport(Report report) async {
    final document = _reports.doc();
    final reportToSave = report.copyWith(
      id: document.id,
      geohash: _geoHasher.encode(
        report.location.longitude,
        report.location.latitude,
        precision: 9,
      ),
    );

    await document.set(reportToSave.toJson());
    return reportToSave;
  }

  Stream<List<Report>> watchVisibleReports() {
    return _reports
        .where('status', whereIn: const ['active', 'confirmed'])
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => Report.fromJson(document.data(), id: document.id),
              )
              .toList(growable: false),
        );
  }

  Stream<Report?> watchReport(String reportId) {
    return _reports.doc(reportId).snapshots().map((document) {
      final data = document.data();
      if (!document.exists || data == null) return null;
      return Report.fromJson(data, id: document.id);
    });
  }

  Future<void> castVote({
    required String reportId,
    required String userId,
    required bool isUpvote,
  }) async {
    final reportReference = _reports.doc(reportId);
    final voteReference = reportReference.collection('votes').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final reportSnapshot = await transaction.get(reportReference);
      final voteSnapshot = await transaction.get(voteReference);
      final reportData = reportSnapshot.data();

      if (!reportSnapshot.exists || reportData == null) {
        throw StateError('This report no longer exists.');
      }
      if (reportData['creatorId'] == userId) {
        throw StateError('You cannot vote on your own report.');
      }

      final previousVote =
          (voteSnapshot.data()?['value'] as num?)?.toInt() ?? 0;
      final nextVote = isUpvote ? 1 : -1;
      if (previousVote == nextVote) return;

      final currentUpvotes = (reportData['upvoteCount'] as num?)?.toInt() ?? 0;
      final currentDownvotes =
          (reportData['downvoteCount'] as num?)?.toInt() ?? 0;
      final upvoteDelta = (nextVote == 1 ? 1 : 0) - (previousVote == 1 ? 1 : 0);
      final downvoteDelta =
          (nextVote == -1 ? 1 : 0) - (previousVote == -1 ? 1 : 0);

      transaction.update(reportReference, <String, Object>{
        'upvoteCount': (currentUpvotes + upvoteDelta).clamp(0, 1 << 31),
        'downvoteCount': (currentDownvotes + downvoteDelta).clamp(0, 1 << 31),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(voteReference, <String, Object>{
        'userId': userId,
        'value': nextVote,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!voteSnapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
