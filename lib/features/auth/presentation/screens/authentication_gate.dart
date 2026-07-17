import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaga/core/theme/app_colors.dart';
import 'package:jaga/features/map/presentation/screens/main_safety_map_screen.dart';
import 'package:jaga/features/pin/application/pin_error_mapper.dart';
import 'package:jaga/features/pin/application/pin_providers.dart';
import 'package:jaga/features/pin/data/models/pin_models.dart';
import 'package:jaga/features/pin/presentation/screens/pin_setup_screen.dart';
import 'package:jaga/features/profile/presentation/screens/profile_settings_screen.dart';

import '../../application/auth_controllers.dart';
import '../../application/auth_providers.dart';
import 'login_screen.dart';
import 'profile_completion_screen.dart';
import 'trusted_contact_onboarding_screen.dart';

class AuthenticationGate extends ConsumerWidget {
  const AuthenticationGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authentication = ref.watch(authenticationStateProvider);

    return authentication.when(
      loading: () => const _GateLoading(),
      error: (_, _) => _GateError(
        onRetry: () => ref.invalidate(authenticationStateProvider),
      ),
      data: (session) {
        if (session == null) {
          return const LoginScreen();
        }

        final registration = ref.watch(registrationControllerProvider);
        if (registration.isLoading) {
          return const _GateLoading();
        }

        final profile = ref.watch(currentUserProfileProvider(session.uid));
        return profile.when(
          loading: () => const _GateLoading(),
          error: (_, _) => _GateError(
            onRetry: () =>
                ref.invalidate(currentUserProfileProvider(session.uid)),
          ),
          data: (userProfile) {
            if (userProfile == null) {
              return ProfileCompletionScreen(
                uid: session.uid,
                email: session.email,
              );
            }

            final trustedContact = ref.watch(
              trustedContactExistsProvider(session.uid),
            );
            return trustedContact.when(
              loading: () => const _GateLoading(),
              error: (_, _) => _GateError(
                onRetry: () =>
                    ref.invalidate(trustedContactExistsProvider(session.uid)),
              ),
              data: (exists) {
                if (!exists) {
                  return TrustedContactOnboardingScreen(uid: session.uid);
                }
                final pinStatus = ref.watch(pinStatusProvider(session.uid));
                return pinStatus.when(
                  loading: () => const _GateLoading(),
                  error: (error, _) => _GateError(
                    title: 'PIN perangkat belum dapat diperiksa',
                    message: error is PinFailure
                        ? mapPinFailure(error, operation: PinOperation.status)
                        : 'Status PIN perangkat belum dapat diperiksa. Coba lagi.',
                    icon: Icons.phonelink_lock_rounded,
                    onRetry: () =>
                        ref.invalidate(pinStatusProvider(session.uid)),
                  ),
                  data: (hasPin) {
                    if (!hasPin) {
                      return PinSetupScreen(
                        uid: session.uid,
                        onSignOut: () => ref
                            .read(signOutControllerProvider.notifier)
                            .signOut(),
                      );
                    }
                    return MainSafetyMapScreen(
                      displayName: userProfile.displayName,
                      onOpenProfile: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ProfileSettingsScreen(uid: session.uid),
                          ),
                        );
                      },
                      onSignOut: () async {
                        return ref
                            .read(signOutControllerProvider.notifier)
                            .signOut();
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _GateLoading extends StatelessWidget {
  const _GateLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFEAF6FF),
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}

class _GateError extends StatelessWidget {
  const _GateError({
    required this.onRetry,
    this.title = 'Jaga belum dapat memuat akunmu',
    this.message = 'Periksa koneksi internet, lalu coba lagi.',
    this.icon = Icons.cloud_off_rounded,
  });

  final VoidCallback onRetry;
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 56, color: Colors.red),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
