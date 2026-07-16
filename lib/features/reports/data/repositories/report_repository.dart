import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/report.dart';

class ReportVoteAuthenticationException implements Exception {
  const ReportVoteAuthenticationException();
}

class ReportVoteTotals {
  const ReportVoteTotals({required this.upvotes, required this.downvotes});

  final int upvotes;
  final int downvotes;
}

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

  Stream<int?> watchCurrentVote({
    required String reportId,
    required String userId,
  }) {
    return _reports
        .doc(reportId)
        .collection('votes')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          final value = (snapshot.data()?['value'] as num?)?.toInt();
          return value == 1 || value == -1 ? value : null;
        });
  }

  Stream<ReportVoteTotals> watchVoteTotals(String reportId) {
    return _reports
        .doc(reportId)
        .collection('votes')
        .snapshots()
        .map((snapshot) {
          var upvotes = 0;
          var downvotes = 0;

          for (final document in snapshot.docs) {
            final value = (document.data()['value'] as num?)?.toInt();
            if (value == 1) {
              upvotes++;
            } else if (value == -1) {
              downvotes++;
            }
          }

          return ReportVoteTotals(
            upvotes: upvotes,
            downvotes: downvotes,
          );
        });
  }

  Future<void> castVote({
    required String reportId,
    required int voteValue,
  }) async {
    if (voteValue != 1 && voteValue != -1) {
      throw ArgumentError.value(voteValue, 'voteValue', 'Must be 1 or -1');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const ReportVoteAuthenticationException();
    }

    final userId = user.uid;
    final voteReference = _reports
        .doc(reportId)
        .collection('votes')
        .doc(userId);

    try {
      debugPrint(
        '[ReportRepository] Resolving vote operation '
        'path=${voteReference.path} requestedValue=$voteValue',
      );
      final voteSnapshot = await voteReference.get();
      final previousVote = (voteSnapshot.data()?['value'] as num?)?.toInt();

      if (previousVote == voteValue) {
        debugPrint(
          '[ReportRepository] Writing vote path=${voteReference.path} '
          'operation=no-op requestedValue=$voteValue',
        );
        debugPrint('[ReportRepository] Vote write succeeded');
        return;
      }

      if (voteSnapshot.exists) {
        debugPrint(
          '[ReportRepository] Writing vote path=${voteReference.path} '
          'operation=update requestedValue=$voteValue',
        );
        await voteReference.update(<String, Object>{'value': voteValue});
      } else {
        debugPrint(
          '[ReportRepository] Writing vote path=${voteReference.path} '
          'operation=create requestedValue=$voteValue',
        );
        await voteReference.set(<String, Object>{
          'value': voteValue,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('[ReportRepository] Vote write succeeded');
    } on FirebaseException catch (error) {
      debugPrint(
        '[ReportRepository] Vote write failed firebaseCode=${error.code} '
        'message=${error.message} reportId=$reportId uid=$userId '
        'requestedValue=$voteValue',
      );
      rethrow;
    }
  }
}
