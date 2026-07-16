import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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
  'accident_prone': ReportCategoryRule(reportType: 'hazard', severity: 3),
  'suspicious_activity': ReportCategoryRule(reportType: 'hazard', severity: 2),
  'harassment': ReportCategoryRule(reportType: 'hazard', severity: 3),
  'other_hazard': ReportCategoryRule(reportType: 'hazard', severity: 2),
  'police_station': ReportCategoryRule(reportType: 'protective', severity: 3),
  'cctv': ReportCategoryRule(reportType: 'protective', severity: 1),
  'security_post': ReportCategoryRule(reportType: 'protective', severity: 2),
  'other_security_presence': ReportCategoryRule(
    reportType: 'protective',
    severity: 1,
  ),
};

final draftLocationProvider = NotifierProvider<DraftLocationNotifier, LatLng?>(
  DraftLocationNotifier.new,
);

class DraftLocationNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  void setLocation(LatLng location) => state = location;

  void clear() => state = null;
}

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(firebaseFirestoreProvider));
});

final visibleReportsProvider = StreamProvider<List<Report>>((ref) {
  return ref.watch(reportRepositoryProvider).watchVisibleReports();
});

final reportDetailProvider = StreamProvider.family<Report?, String>((
  ref,
  reportId,
) {
  return ref.watch(reportRepositoryProvider).watchReport(reportId);
});

final currentReportVoteProvider = StreamProvider.family<int?, String>((
  ref,
  reportId,
) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return Stream<int?>.value(null);

  return ref
      .watch(reportRepositoryProvider)
      .watchCurrentVote(reportId: reportId, userId: user.uid);
});

final reportVoteTotalsProvider =
    StreamProvider.family<ReportVoteTotals, String>((ref, reportId) {
      return ref.watch(reportRepositoryProvider).watchVoteTotals(reportId);
    });

final reportControllerProvider =
    AsyncNotifierProvider<ReportController, Report?>(ReportController.new);

class ReportController extends AsyncNotifier<Report?> {
  @override
  FutureOr<Report?> build() => null;

  Future<Report> submitReport(
    LatLng location,
    String category,
    String description,
  ) async {
    if (state.isLoading) {
      throw StateError('A report submission is already in progress.');
    }

    state = const AsyncLoading();
    try {
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

      final savedReport = await ref
          .read(reportRepositoryProvider)
          .addReport(report);
      state = AsyncData(savedReport);
      return savedReport;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

enum ReportOwnerOperation { idle, editing, deleting }

class ReportOwnerActionState {
  const ReportOwnerActionState({
    this.operation = ReportOwnerOperation.idle,
    this.failure,
  });

  final ReportOwnerOperation operation;
  final ReportOwnerActionFailure? failure;

  bool get isEditing => operation == ReportOwnerOperation.editing;
  bool get isDeleting => operation == ReportOwnerOperation.deleting;
  bool get isBusy => operation != ReportOwnerOperation.idle;
}

final reportOwnerActionControllerProvider =
    NotifierProvider<
      ReportOwnerActionController,
      Map<String, ReportOwnerActionState>
    >(ReportOwnerActionController.new);

class ReportOwnerActionController
    extends Notifier<Map<String, ReportOwnerActionState>> {
  @override
  Map<String, ReportOwnerActionState> build() =>
      const <String, ReportOwnerActionState>{};

  Future<bool> updateDescription({
    required Report report,
    required String description,
  }) async {
    if (_stateFor(report.id).isBusy) return false;

    final validationFailure = _ownerFailure(report, requireActive: true);
    final trimmedDescription = description.trim();
    if (validationFailure != null) {
      _setState(report.id, ReportOwnerActionState(failure: validationFailure));
      return false;
    }
    if (trimmedDescription.isEmpty || trimmedDescription.length > 500) {
      _setState(
        report.id,
        const ReportOwnerActionState(
          failure: ReportOwnerActionFailure.invalidDescription,
        ),
      );
      return false;
    }

    _setState(
      report.id,
      const ReportOwnerActionState(operation: ReportOwnerOperation.editing),
    );
    try {
      await ref
          .read(reportRepositoryProvider)
          .updateOwnReportDescription(
            reportId: report.id,
            description: trimmedDescription,
          );
      _setState(report.id, const ReportOwnerActionState());
      return true;
    } on ReportOwnerActionException catch (error) {
      _setState(
        report.id,
        ReportOwnerActionState(failure: error.failure),
      );
      return false;
    } catch (error) {
      debugPrint(
        '[ReportOwnerActionController] Edit failed reportId=${report.id} '
        'errorType=${error.runtimeType}',
      );
      _setState(
        report.id,
        const ReportOwnerActionState(
          failure: ReportOwnerActionFailure.unknown,
        ),
      );
      return false;
    }
  }

  Future<bool> deleteReport({required Report report}) async {
    if (_stateFor(report.id).isBusy) return false;

    final validationFailure = _ownerFailure(report);
    if (validationFailure != null) {
      _setState(report.id, ReportOwnerActionState(failure: validationFailure));
      return false;
    }

    _setState(
      report.id,
      const ReportOwnerActionState(operation: ReportOwnerOperation.deleting),
    );
    try {
      await ref
          .read(reportRepositoryProvider)
          .deleteOwnReport(reportId: report.id);
      _setState(report.id, const ReportOwnerActionState());
      return true;
    } on ReportOwnerActionException catch (error) {
      _setState(
        report.id,
        ReportOwnerActionState(failure: error.failure),
      );
      return false;
    } catch (error) {
      debugPrint(
        '[ReportOwnerActionController] Delete failed reportId=${report.id} '
        'errorType=${error.runtimeType}',
      );
      _setState(
        report.id,
        const ReportOwnerActionState(
          failure: ReportOwnerActionFailure.unknown,
        ),
      );
      return false;
    }
  }

  ReportOwnerActionFailure? _ownerFailure(
    Report report, {
    bool requireActive = false,
  }) {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return ReportOwnerActionFailure.unauthenticated;
    if (user.uid != report.creatorId) return ReportOwnerActionFailure.notOwner;
    if (requireActive && report.status != 'active') {
      return ReportOwnerActionFailure.notActive;
    }
    if (report.status == 'deleted') {
      return ReportOwnerActionFailure.alreadyDeleted;
    }
    return null;
  }

  ReportOwnerActionState _stateFor(String reportId) =>
      state[reportId] ?? const ReportOwnerActionState();

  void _setState(String reportId, ReportOwnerActionState actionState) {
    state = <String, ReportOwnerActionState>{
      ...state,
      reportId: actionState,
    };
  }
}

final reportVoteControllerProvider =
    NotifierProvider<
      ReportVoteController,
      Map<String, AsyncValue<void>>
    >(ReportVoteController.new);

class ReportVoteAuthenticationRequiredException implements Exception {
  const ReportVoteAuthenticationRequiredException();
}

class ReportVoteController
    extends Notifier<Map<String, AsyncValue<void>>> {
  @override
  Map<String, AsyncValue<void>> build() =>
      const <String, AsyncValue<void>>{};

  Future<void> vote({required String reportId, required int voteValue}) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    final currentVote = ref.read(currentReportVoteProvider(reportId)).value;
    debugPrint(
      '[ReportVoteController] Vote controller invoked reportId=$reportId '
      'uid=${user?.uid ?? 'unauthenticated'} requestedValue=$voteValue '
      'currentVote=$currentVote',
    );

    final currentRequest = state[reportId];
    if (currentRequest?.isLoading ?? false) return;

    if (user == null) {
      _setRequestState(
        reportId,
        AsyncError<void>(
          const ReportVoteAuthenticationRequiredException(),
          StackTrace.current,
        ),
      );
      return;
    }

    _setRequestState(reportId, const AsyncLoading<void>());
    try {
      await ref
          .read(reportRepositoryProvider)
          .castVote(reportId: reportId, voteValue: voteValue);
      _setRequestState(reportId, const AsyncData<void>(null));
    } on ReportVoteAuthenticationException catch (_, stackTrace) {
      _setRequestState(
        reportId,
        AsyncError<void>(
          const ReportVoteAuthenticationRequiredException(),
          stackTrace,
        ),
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[ReportVoteController] Vote write failed reportId=$reportId '
        'uid=${user.uid} requestedValue=$voteValue '
        'firebaseCode=${error.code}',
      );
      _setRequestState(reportId, AsyncError<void>(error, stackTrace));
    } catch (error, stackTrace) {
      debugPrint(
        '[ReportVoteController] Vote write failed reportId=$reportId '
        'uid=${user.uid} requestedValue=$voteValue '
        'errorType=${error.runtimeType}',
      );
      _setRequestState(reportId, AsyncError<void>(error, stackTrace));
    }
  }

  void _setRequestState(String reportId, AsyncValue<void> requestState) {
    state = <String, AsyncValue<void>>{
      ...state,
      reportId: requestState,
    };
  }
}
