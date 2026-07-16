import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_controllers.dart';
import '../../application/auth_validators.dart';
import '../widgets/auth_form_widgets.dart';
import '../widgets/auth_page_scaffold.dart';

class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({
    required this.uid,
    required this.email,
    super.key,
  });

  final String uid;
  final String email;

  @override
  ConsumerState<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState
    extends ConsumerState<ProfileCompletionScreen> {
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
        .read(profileRecoveryControllerProvider.notifier)
        .completeProfile(
          uid: widget.uid,
          email: widget.email,
          displayName: _displayNameController.text.trim(),
          phoneNumber: phoneNumber,
        );
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(profileRecoveryControllerProvider);
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
      title: 'Lengkapi profilmu',
      subtitle:
          'Data profil akun belum ditemukan. Lengkapi data berikut untuk melanjutkan dengan aman.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _displayNameController,
              enabled: !isBusy,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.nickname],
              validator: validateDisplayName,
              decoration: authInputDecoration(
                label: 'Nama panggilan',
                icon: Icons.person_outline_rounded,
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
              label: 'Simpan profil',
              isLoading: request.isLoading,
              onPressed: isBusy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
