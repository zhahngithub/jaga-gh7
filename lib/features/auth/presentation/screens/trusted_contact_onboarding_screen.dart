import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_controllers.dart';
import '../../application/auth_validators.dart';
import '../widgets/auth_form_widgets.dart';
import '../widgets/auth_page_scaffold.dart';

class TrustedContactOnboardingScreen extends ConsumerStatefulWidget {
  const TrustedContactOnboardingScreen({required this.uid, super.key});

  final String uid;

  @override
  ConsumerState<TrustedContactOnboardingScreen> createState() =>
      _TrustedContactOnboardingScreenState();
}

class _TrustedContactOnboardingScreenState
    extends ConsumerState<TrustedContactOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final phoneNumber = normalizeIndonesianPhone(_phoneController.text);
    if (phoneNumber == null) {
      return;
    }
    await ref
        .read(trustedContactControllerProvider.notifier)
        .saveContact(
          uid: widget.uid,
          displayName: _displayNameController.text.trim(),
          phoneNumber: phoneNumber,
        );
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(trustedContactControllerProvider);
    final signOutRequest = ref.watch(signOutControllerProvider);
    final isBusy = request.isLoading || signOutRequest.isLoading;

    return AuthPageScaffold(
      trailing: TextButton.icon(
        onPressed: isBusy
            ? null
            : () => ref.read(signOutControllerProvider.notifier).signOut(),
        icon: signOutRequest.isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout_rounded),
        label: const Text('Keluar'),
      ),
      title: 'Siapa yang kamu percaya?',
      subtitle:
          'Langkah 2 dari 2 · Tambahkan minimal satu kontak darurat sebelum mulai menggunakan peta.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF006BCB),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Kontak hanya disimpan sebagai kontak tepercaya. Jaga tidak mengirim SMS pada tahap ini.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF07558F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _displayNameController,
              enabled: !isBusy,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama kontak darurat wajib diisi.';
                }
                return null;
              },
              decoration: authInputDecoration(
                label: 'Nama kontak darurat',
                icon: Icons.contact_phone_outlined,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              enabled: !isBusy,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: validateIndonesianPhone,
              onFieldSubmitted: (_) => _submit(),
              decoration: authInputDecoration(
                label: 'Nomor telepon',
                icon: Icons.phone_outlined,
                hint: '081234567890',
              ),
            ),
            if (request.errorMessage != null ||
                signOutRequest.errorMessage != null) ...[
              const SizedBox(height: 18),
              RequestMessageContainer(
                errorMessage:
                    request.errorMessage ?? signOutRequest.errorMessage,
              ),
            ],
            const SizedBox(height: 22),
            AuthPrimaryButton(
              label: 'Simpan dan mulai',
              isLoading: request.isLoading,
              onPressed: isBusy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
