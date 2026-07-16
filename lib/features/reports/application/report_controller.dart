import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../auth/application/auth_providers.dart';
import '../data/models/report.dart';
import '../data/repositories/report_repository.dart';

class ReportCategoryRule {
  const ReportCategoryRule({required this.reportType, required this.severity});

  final String reportType;
  final int severity;
}

const reportCategoryRules = <String, ReportCategoryRule>{
  'poor_lighting': ReportCategoryRule(reportType: 'hazard', severity: 2),
  'damaged_road': ReportCategoryRule(reportType: 'hazard', severity: 2),
  'harassment': ReportCategoryRule(reportType: 'hazard', severity: 3),
  'police_station': ReportCategoryRule(reportType: 'protective', severity: 3),
  'cctv': ReportCategoryRule(reportType: 'protective', severity: 1),
};

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(firebaseFirestoreProvider));
});

final visibleReportsProvider = StreamProvider<List<Report>>((ref) {
  return ref.watch(reportRepositoryProvider).watchVisibleReports();
});

final reportControllerProvider = AsyncNotifierProvider<ReportController, void>(
  ReportController.new,
);

class ReportController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> submitReport(
    LatLng location,
    String category,
    String description,
  ) async {
    if (state.isLoading) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) {
        throw StateError('You must be signed in to submit a report.');
      }

      final categoryRule = reportCategoryRules[category];
      if (categoryRule == null) {
        throw ArgumentError.value(category, 'category', 'Unsupported category');
      }

      final trimmedDescription = description.trim();
      if (trimmedDescription.isEmpty) {
        throw ArgumentError('Description cannot be empty.');
      }

      final now = DateTime.now().toUtc();
      final report = Report(
        id: '',
        creatorId: user.uid,
        category: category,
        reportType: categoryRule.reportType,
        severity: categoryRule.severity,
        description: trimmedDescription,
        location: GeoPoint(location.latitude, location.longitude),
        geohash: '',
        status: 'active',
        upvoteCount: 0,
        downvoteCount: 0,
        confidenceScore: 0.0,
        createdAt: now,
        updatedAt: now,
      );

      await ref.read(reportRepositoryProvider).addReport(report);
    });
  }
}
