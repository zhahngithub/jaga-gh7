import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_controllers.dart';
import '../../application/auth_validators.dart';
import '../widgets/auth_form_widgets.dart';
import '../widgets/auth_page_scaffold.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
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

    final succeeded = await ref
        .read(registrationControllerProvider.notifier)
        .register(
          displayName: _displayNameController.text.trim(),
          phoneNumber: phoneNumber,
          email: normalizeEmail(_emailController.text),
          password: _passwordController.text,
        );

    if (succeeded && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(registrationControllerProvider);

    return AuthPageScaffold(
      leading: const AuthBackButton(),
      title: 'Buat akun Jaga',
      subtitle:
          'Langkah 1 dari 3 \u00B7 Isi data akun, lalu lanjutkan pengaturan keamanan.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _displayNameController,
                enabled: !request.isLoading,
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
                enabled: !request.isLoading,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: validateIndonesianPhone,
                decoration: authInputDecoration(
                  label: 'Nomor telepon',
                  icon: Icons.phone_outlined,
                  hint: '081234567890',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                enabled: !request.isLoading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newUsername],
                autocorrect: false,
                validator: validateEmail,
                decoration: authInputDecoration(
                  label: 'Email',
                  icon: Icons.alternate_email_rounded,
                  hint: 'nama@email.com',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                enabled: !request.isLoading,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: validatePassword,
                decoration: authInputDecoration(
                  label: 'Kata sandi',
                  icon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Tampilkan kata sandi'
                        : 'Sembunyikan kata sandi',
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmationController,
                enabled: !request.isLoading,
                obscureText: _obscureConfirmation,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) => validatePasswordConfirmation(
                  password: _passwordController.text,
                  confirmation: value,
                ),
                onFieldSubmitted: (_) => _submit(),
                decoration: authInputDecoration(
                  label: 'Konfirmasi kata sandi',
                  icon: Icons.lock_reset_rounded,
                  suffixIcon: IconButton(
                    tooltip: _obscureConfirmation
                        ? 'Tampilkan konfirmasi'
                        : 'Sembunyikan konfirmasi',
                    onPressed: () {
                      setState(
                        () => _obscureConfirmation = !_obscureConfirmation,
                      );
                    },
                    icon: Icon(
                      _obscureConfirmation
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              if (request.errorMessage != null) ...[
                const SizedBox(height: 18),
                RequestMessageContainer(errorMessage: request.errorMessage),
              ],
              const SizedBox(height: 22),
              AuthPrimaryButton(
                label: 'Lanjutkan',
                isLoading: request.isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
