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
}
