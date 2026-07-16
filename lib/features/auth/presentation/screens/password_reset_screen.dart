import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_controllers.dart';
import '../../application/auth_validators.dart';
import '../widgets/auth_form_widgets.dart';
import '../widgets/auth_page_scaffold.dart';

class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await ref
        .read(passwordResetControllerProvider.notifier)
        .sendResetEmail(normalizeEmail(_emailController.text));
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(passwordResetControllerProvider);

    return AuthPageScaffold(
      leading: const AuthBackButton(),
      title: 'Atur ulang kata sandi',
      subtitle:
          'Masukkan email akunmu. Kami akan memproses permintaan tautan pengaturan ulang.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              enabled: !request.isLoading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              validator: validateEmail,
              onFieldSubmitted: (_) => _submit(),
              decoration: authInputDecoration(
                label: 'Email',
                icon: Icons.alternate_email_rounded,
                hint: 'nama@email.com',
              ),
            ),
            if (request.errorMessage != null ||
                request.successMessage != null) ...[
              const SizedBox(height: 18),
              RequestMessageContainer(
                errorMessage: request.errorMessage,
                successMessage: request.successMessage,
              ),
            ],
            const SizedBox(height: 22),
            AuthPrimaryButton(
              label: 'Kirim tautan reset',
              isLoading: request.isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
