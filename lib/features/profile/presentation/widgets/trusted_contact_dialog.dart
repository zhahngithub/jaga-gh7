import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/profile_controllers.dart';
import '../../application/profile_validation.dart';
import '../../data/models/profile_trusted_contact.dart';
import 'profile_components.dart';

class TrustedContactDialog extends ConsumerStatefulWidget {
  const TrustedContactDialog({required this.uid, this.contact, super.key});

  final String uid;
  final ProfileTrustedContact? contact;

  @override
  ConsumerState<TrustedContactDialog> createState() =>
      _TrustedContactDialogState();
}

class _TrustedContactDialogState extends ConsumerState<TrustedContactDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  bool get _isEditing => widget.contact != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?.displayName);
    _phoneController = TextEditingController(text: widget.contact?.phoneNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final controller = ref.read(
      trustedContactMutationControllerProvider.notifier,
    );
    final succeeded = _isEditing
        ? await controller.update(
            uid: widget.uid,
            contactId: widget.contact!.id,
            displayNameInput: _nameController.text,
            phoneInput: _phoneController.text,
          )
        : await controller.create(
            uid: widget.uid,
            displayNameInput: _nameController.text,
            phoneInput: _phoneController.text,
          );

    if (succeeded && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(trustedContactMutationControllerProvider);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(_isEditing ? 'Edit kontak' : 'Tambah kontak'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !request.isSubmitting,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofocus: true,
                  validator: validateTrustedContactName,
                  decoration: profileInputDecoration(
                    label: 'Nama kontak',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  enabled: !request.isSubmitting,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  validator: validateProfilePhone,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: profileInputDecoration(
                    label: 'Nomor telepon',
                    icon: Icons.phone_outlined,
                    hint: '081234567890',
                  ),
                ),
                if (request.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  ProfileMessage(errorMessage: request.errorMessage),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: request.isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: request.isSubmitting ? null : _submit,
          child: request.isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.2,
                  ),
                )
              : Text(_isEditing ? 'Simpan' : 'Tambah'),
        ),
      ],
    );
  }
}
