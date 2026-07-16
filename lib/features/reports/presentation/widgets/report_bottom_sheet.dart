import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../application/report_controller.dart';

class ReportBottomSheet extends ConsumerStatefulWidget {
  const ReportBottomSheet({required this.location, super.key});

  final LatLng location;

  @override
  ConsumerState<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends ConsumerState<ReportBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  String? _submissionError;

  static const _categoryLabels = <String, String>{
    'poor_lighting': 'Poor lighting',
    'accident_prone': 'Accident prone',
    'suspicious_activity': 'Suspicious activity',
    'harassment': 'Harassment',
    'other_hazard': 'Other hazard',
    'cctv': 'CCTV',
    'police_station': 'Police station',
    'security_post': 'Security post',
    'other_security_presence': 'Other security presence',
  };

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    debugPrint('[ReportBottomSheet] Submit button pressed.');

    if (_submissionError != null) {
      setState(() => _submissionError = null);
    }

    final formState = _formKey.currentState;
    if (formState == null) {
      debugPrint('[ReportBottomSheet] Validation failed: form state is null.');
      _showSubmissionError('Report form is not ready.');
      return;
    }

    final isFormValid = formState.validate();
    final category = _selectedCategory;
    final description = _descriptionController.text.trim();

    if (!isFormValid || category == null || description.isEmpty) {
      debugPrint(
        '[ReportBottomSheet] Validation failed. '
        'category=$category, descriptionLength=${description.length}',
      );
      return;
    }

    debugPrint(
      '[ReportBottomSheet] Validation succeeded. '
      'category=$category, descriptionLength=${description.length}',
    );

    try {
      debugPrint('[ReportBottomSheet] Calling ReportController.submitReport.');

      final savedReport = await ref
          .read(reportControllerProvider.notifier)
          .submitReport(widget.location, category, description);

      debugPrint(
        '[ReportBottomSheet] ReportController call completed. '
        'reportId=${savedReport.id}',
      );

      if (!mounted) {
        debugPrint(
          '[ReportBottomSheet] Widget unmounted after controller call.',
        );
        return;
      }

      if (savedReport.id.isEmpty) {
        throw StateError('Firestore did not return a report document ID.');
      }

      debugPrint('[ReportBottomSheet] Submission succeeded.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report submitted.')));
      ref.read(draftLocationProvider.notifier).clear();
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint('[ReportBottomSheet] Submission error caught: $error');
      debugPrintStack(
        label: '[ReportBottomSheet] Submission stack trace',
        stackTrace: stackTrace,
      );

      if (mounted) {
        _showSubmissionError(error);
      }
    }
  }

  void _showSubmissionError(Object error) {
    final message = error.toString();
    setState(() => _submissionError = message);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final submission = ref.watch(reportControllerProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Report this location',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categoryLabels.entries
                    .map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: submission.isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _selectedCategory = value;
                          _submissionError = null;
                        });
                      },
                validator: (value) =>
                    value == null ? 'Select a report category.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                enabled: !submission.isLoading,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe what you observed...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_submissionError != null) {
                    setState(() => _submissionError = null);
                  }
                },
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a short description.'
                    : null,
              ),
              const SizedBox(height: 8),
              if (_submissionError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _submissionError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: submission.isLoading ? null : _submit,
                icon: submission.isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_location_alt),
                label: Text(
                  submission.isLoading ? 'Submitting...' : 'Submit report',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
