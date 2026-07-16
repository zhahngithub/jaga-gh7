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

  static const _categoryLabels = <String, String>{
    'poor_lighting': 'Poor lighting',
    'damaged_road': 'Damaged road',
    'harassment': 'Harassment',
    'police_station': 'Police station',
    'cctv': 'CCTV',
  };

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(reportControllerProvider.notifier)
        .submitReport(
          widget.location,
          _selectedCategory!,
          _descriptionController.text,
        );

    if (!mounted) return;

    final result = ref.read(reportControllerProvider);
    if (result.hasError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error.toString())));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Report submitted.')));
    Navigator.of(context).pop();
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
                    : (value) => setState(() => _selectedCategory = value),
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
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a short description.'
                    : null,
              ),
              const SizedBox(height: 8),
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
