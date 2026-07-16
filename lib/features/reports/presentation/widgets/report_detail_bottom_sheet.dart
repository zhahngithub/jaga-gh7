import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_providers.dart';
import '../../application/report_controller.dart';
import '../../data/models/report.dart';

const _indonesianMonthAbbreviations = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String _createdAtLabel(DateTime? createdAt) {
  if (createdAt == null) return 'Dibuat: Tanggal tidak tersedia';

  final localDate = createdAt.toLocal();
  final day = localDate.day.toString().padLeft(2, '0');
  final hour = localDate.hour.toString().padLeft(2, '0');
  final minute = localDate.minute.toString().padLeft(2, '0');
  final month = _indonesianMonthAbbreviations[localDate.month - 1];

  return 'Dibuat: $day $month ${localDate.year}, $hour.$minute';
}

class ReportDetailBottomSheet extends ConsumerWidget {
  const ReportDetailBottomSheet({required this.initialReport, super.key});

  final Report initialReport;

  Future<void> _vote(
    BuildContext context,
    WidgetRef ref, {
    required int voteValue,
  }) async {
    debugPrint(
      '[ReportDetailBottomSheet] Vote button pressed '
      'reportId=${initialReport.id} requestedValue=$voteValue',
    );
    await ref
        .read(reportVoteControllerProvider.notifier)
        .vote(reportId: initialReport.id, voteValue: voteValue);

    if (!context.mounted) return;
    final result =
        ref.read(reportVoteControllerProvider)[initialReport.id] ??
        const AsyncData<void>(null);
    if (result.hasError) {
      final message =
          result.error is ReportVoteAuthenticationRequiredException
          ? 'Silakan masuk untuk memberikan suara.'
          : 'Gagal menyimpan suara. Silakan coba lagi.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(reportDetailProvider(initialReport.id));
    final report = reportAsync.value ?? initialReport;
    final currentUser = ref.watch(firebaseAuthProvider).currentUser;
    final currentVoteState = ref.watch(
      currentReportVoteProvider(initialReport.id),
    );
    final voteTotalsState = ref.watch(
      reportVoteTotalsProvider(initialReport.id),
    );
    final selectedVote = currentVoteState.value;
    final voteTotals = voteTotalsState.value;
    final upvoteTotal = voteTotals?.upvotes.toString() ?? '…';
    final downvoteTotal = voteTotals?.downvotes.toString() ?? '…';
    final voteState =
        ref.watch(reportVoteControllerProvider)[initialReport.id] ??
        const AsyncData<void>(null);
    final isSubmittingVote = voteState.isLoading || currentVoteState.isLoading;
    final isUpvoted = selectedVote == 1;
    final isDownvoted = selectedVote == -1;
    final canVote = currentUser?.uid != report.creatorId;
    final colorScheme = Theme.of(context).colorScheme;

    ButtonStyle voteButtonStyle(bool isSelected) => OutlinedButton.styleFrom(
      backgroundColor: isSelected ? colorScheme.primaryContainer : null,
      foregroundColor: isSelected
          ? colorScheme.onPrimaryContainer
          : colorScheme.primary,
      side: BorderSide(
        color: isSelected ? colorScheme.primary : colorScheme.outline,
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              report.category.replaceAll('_', ' '),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(report.description),
            const SizedBox(height: 8),
            Text(
              _createdAtLabel(report.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Text('Upvotes: $upvoteTotal')),
                Expanded(child: Text('Downvotes: $downvoteTotal')),
              ],
            ),
            if (canVote) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: voteButtonStyle(isUpvoted),
                      onPressed: isSubmittingVote
                          ? null
                          : () => _vote(context, ref, voteValue: 1),
                      icon: const Icon(Icons.thumb_up),
                      label: const Text('Upvote'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: voteButtonStyle(isDownvoted),
                      onPressed: isSubmittingVote
                          ? null
                          : () => _vote(context, ref, voteValue: -1),
                      icon: const Icon(Icons.thumb_down),
                      label: const Text('Downvote'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
