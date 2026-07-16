import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_controllers.dart';
import '../../application/auth_validators.dart';
import '../widgets/auth_form_widgets.dart';
import '../widgets/auth_page_scaffold.dart';
import 'password_reset_screen.dart';
import 'registration_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await ref
        .read(loginControllerProvider.notifier)
        .signIn(
          email: normalizeEmail(_emailController.text),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(loginControllerProvider);

    return AuthPageScaffold(
      title: 'Masuk untuk tetap terlindungi',
      subtitle:
          'Akses perjalanan aman dan kontak tepercaya kamu dalam satu akun.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                enabled: !request.isLoading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
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
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: validatePassword,
                onFieldSubmitted: (_) => _submit(),
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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: request.isLoading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PasswordResetScreen(),
                            ),
                          );
                        },
                  child: const Text('Lupa kata sandi?'),
                ),
              ),
              RequestMessageContainer(errorMessage: request.errorMessage),
              if (request.errorMessage != null) const SizedBox(height: 16),
              AuthPrimaryButton(
                label: 'Masuk',
                isLoading: request.isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Flexible(child: Text('Belum punya akun?')),
                  TextButton(
                    onPressed: request.isLoading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RegistrationScreen(),
                              ),
                            );
                          },
                    child: const Text('Buat akun'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
