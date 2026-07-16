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
    required bool isUpvote,
  }) async {
    await ref
        .read(reportVoteControllerProvider.notifier)
        .vote(reportId: initialReport.id, isUpvote: isUpvote);

    if (!context.mounted) return;
    final result = ref.read(reportVoteControllerProvider);
    if (result.hasError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(reportDetailProvider(initialReport.id));
    final report = reportAsync.value ?? initialReport;
    final currentUser = ref.watch(firebaseAuthProvider).currentUser;
    final voteState = ref.watch(reportVoteControllerProvider);
    final canVote = currentUser != null && currentUser.uid != report.creatorId;

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
                Expanded(child: Text('Upvotes: ${report.upvoteCount}')),
                Expanded(child: Text('Downvotes: ${report.downvoteCount}')),
              ],
            ),
            if (canVote) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: voteState.isLoading
                          ? null
                          : () => _vote(context, ref, isUpvote: true),
                      icon: const Icon(Icons.thumb_up),
                      label: const Text('Upvote'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: voteState.isLoading
                          ? null
                          : () => _vote(context, ref, isUpvote: false),
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
