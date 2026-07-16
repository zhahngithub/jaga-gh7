import 'dart:async';

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

enum _OwnerAction { edit, delete }

class ReportDetailBottomSheet extends ConsumerWidget {
  const ReportDetailBottomSheet({required this.initialReport, super.key});

  final Report initialReport;

  Future<void> _editReport(BuildContext context, Report report) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _EditReportDialog(report: report),
    );
    if (!context.mounted || updated != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Laporan berhasil diperbarui.')),
    );
  }

  Future<void> _deleteReport(BuildContext context, Report report) async {
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteReportDialog(report: report),
    );
    if (!context.mounted || deleted != true) return;

    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Laporan berhasil dihapus.')),
    );
  }

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
    final isOwner = currentUser != null && currentUser.uid == report.creatorId;
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.category.replaceAll('_', ' '),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isOwner)
                  PopupMenuButton<_OwnerAction>(
                    tooltip: 'Tindakan laporan',
                    onSelected: (action) {
                      switch (action) {
                        case _OwnerAction.edit:
                          unawaited(_editReport(context, report));
                          break;
                        case _OwnerAction.delete:
                          unawaited(_deleteReport(context, report));
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem<_OwnerAction>(
                        value: _OwnerAction.edit,
                        enabled: report.status == 'active',
                        child: const Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 12),
                            Text('Edit laporan'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<_OwnerAction>(
                        value: _OwnerAction.delete,
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline),
                            SizedBox(width: 12),
                            Text('Hapus laporan'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
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

class _EditReportDialog extends ConsumerStatefulWidget {
  const _EditReportDialog({required this.report});

  final Report report;

  @override
  ConsumerState<_EditReportDialog> createState() =>
      _EditReportDialogState();
}

class _EditReportDialogState extends ConsumerState<_EditReportDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.report.description,
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final updated = await ref
        .read(reportOwnerActionControllerProvider.notifier)
        .updateDescription(
          report: widget.report,
          description: _descriptionController.text,
        );
    if (!mounted) return;

    if (updated) {
      Navigator.of(context).pop(true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gagal memperbarui laporan. Silakan coba lagi.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actionState =
        ref.watch(reportOwnerActionControllerProvider)[widget.report.id] ??
        const ReportOwnerActionState();

    return AlertDialog(
      title: const Text('Edit laporan'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _descriptionController,
          autofocus: true,
          maxLength: 500,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Deskripsi'),
          validator: (value) {
            final description = value?.trim() ?? '';
            if (description.isEmpty) return 'Deskripsi tidak boleh kosong.';
            if (description.length > 500) {
              return 'Deskripsi maksimal 500 karakter.';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: actionState.isEditing
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: actionState.isEditing ? null : _save,
          child: actionState.isEditing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

class _DeleteReportDialog extends ConsumerWidget {
  const _DeleteReportDialog({required this.report});

  final Report report;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final deleted = await ref
        .read(reportOwnerActionControllerProvider.notifier)
        .deleteReport(report: report);
    if (!context.mounted) return;

    if (deleted) {
      Navigator.of(context).pop(true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gagal menghapus laporan. Silakan coba lagi.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState =
        ref.watch(reportOwnerActionControllerProvider)[report.id] ??
        const ReportOwnerActionState();

    return AlertDialog(
      title: const Text('Hapus laporan?'),
      content: const Text(
        'Laporan ini akan dihapus dari peta dan tidak lagi digunakan dalam '
        'penilaian risiko.',
      ),
      actions: [
        TextButton(
          onPressed: actionState.isDeleting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: actionState.isDeleting
              ? null
              : () => _delete(context, ref),
          child: actionState.isDeleting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Hapus'),
        ),
      ],
    );
  }
}
