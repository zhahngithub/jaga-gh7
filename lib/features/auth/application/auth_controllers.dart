import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/trusted_contact.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/auth_repository.dart';
import 'auth_providers.dart';
import 'firebase_auth_error_mapper.dart';
import 'request_state.dart';

final registrationControllerProvider =
    NotifierProvider<RegistrationController, RequestState>(
      RegistrationController.new,
    );

final loginControllerProvider = NotifierProvider<LoginController, RequestState>(
  LoginController.new,
);

final passwordResetControllerProvider =
    NotifierProvider<PasswordResetController, RequestState>(
      PasswordResetController.new,
    );

final profileRecoveryControllerProvider =
    NotifierProvider<ProfileRecoveryController, RequestState>(
      ProfileRecoveryController.new,
    );

final trustedContactControllerProvider =
    NotifierProvider<TrustedContactController, RequestState>(
      TrustedContactController.new,
    );

final signOutControllerProvider =
    NotifierProvider<SignOutController, RequestState>(SignOutController.new);

abstract class RequestController extends Notifier<RequestState> {
  @override
  RequestState build() => RequestState.idle;

  bool startRequest() {
    if (state.isLoading) {
      return false;
    }
    state = RequestState.loading;
    return true;
  }

  void clearMessage() {
    if (!state.isLoading) {
      state = RequestState.idle;
    }
  }

  void handleAuthError(FirebaseAuthException error) {
    state = RequestState.error(mapFirebaseAuthError(error.code));
  }

  void handleUnknownError() {
    state = RequestState.error(
      'Terjadi kendala saat memproses permintaan. Silakan coba lagi.',
    );
  }
}

class RegistrationController extends RequestController {
  Future<bool> register({
    required String displayName,
    required String phoneNumber,
    required String email,
    required String password,
  }) async {
    if (!startRequest()) {
      return false;
    }

    final authRepository = ref.read(authRepositoryProvider);
    final userRepository = ref.read(userRepositoryProvider);
    var accountCreated = false;
    var profileCreated = false;

    try {
      final session = await authRepository.createAccount(
        email: email,
        password: password,
      );
      accountCreated = true;

      await authRepository.updateDisplayName(displayName);
      await userRepository.createUserProfile(
        UserProfile(
          uid: session.uid,
          displayName: displayName,
          email: email,
          phoneNumber: phoneNumber,
          photoUrl: null,
          helperModeEnabled: false,
          communityAssistanceEnabled: false,
        ),
      );
      profileCreated = true;

      try {
        await authRepository.sendEmailVerification();
      } on Object {
        // Email verification is requested, but it does not block account access.
      }

      ref.invalidate(currentUserProfileProvider(session.uid));
      ref.invalidate(trustedContactExistsProvider(session.uid));
      state = RequestState.idle;
      return true;
    } on FirebaseAuthException catch (error) {
      if (accountCreated && !profileCreated) {
        await _tryDeleteCreatedAccount(authRepository);
      }
      handleAuthError(error);
      return false;
    } on Object {
      if (accountCreated && !profileCreated) {
        await _tryDeleteCreatedAccount(authRepository);
        state = RequestState.error(
          'Profil akun belum dapat dibuat. Akun baru dibatalkan agar kamu dapat mencoba lagi.',
        );
      } else {
        handleUnknownError();
      }
      return false;
    }
  }

  Future<void> _tryDeleteCreatedAccount(AuthRepository authRepository) async {
    try {
      await authRepository.deleteCurrentUser();
    } on Object {
      // The original friendly registration error remains the user-facing error.
    }
  }
}

class LoginController extends RequestController {
  Future<bool> signIn({required String email, required String password}) async {
    if (!startRequest()) {
      return false;
    }
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      state = RequestState.idle;
      return true;
    } on FirebaseAuthException catch (error) {
      handleAuthError(error);
      return false;
    } on Object {
      handleUnknownError();
      return false;
    }
  }
}

class PasswordResetController extends RequestController {
  Future<bool> sendResetEmail(String email) async {
    if (!startRequest()) {
      return false;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      state = RequestState.success(
        'Permintaan pengaturan ulang kata sandi telah diproses. Periksa email kamu.',
      );
      return true;
    } on FirebaseAuthException catch (error) {
      handleAuthError(error);
      return false;
    } on Object {
      handleUnknownError();
      return false;
    }
  }
}

class ProfileRecoveryController extends RequestController {
  Future<bool> completeProfile({
    required String uid,
    required String email,
    required String displayName,
    required String phoneNumber,
  }) async {
    if (!startRequest()) {
      return false;
    }
    try {
      await ref.read(authRepositoryProvider).updateDisplayName(displayName);
      await ref
          .read(userRepositoryProvider)
          .createUserProfile(
            UserProfile(
              uid: uid,
              displayName: displayName,
              email: email,
              phoneNumber: phoneNumber,
              photoUrl: null,
              helperModeEnabled: false,
              communityAssistanceEnabled: false,
            ),
          );
      ref.invalidate(currentUserProfileProvider(uid));
      state = RequestState.idle;
      return true;
    } on FirebaseAuthException catch (error) {
      handleAuthError(error);
      return false;
    } on Object {
      state = RequestState.error(
        'Profil belum dapat disimpan. Periksa koneksi lalu coba lagi.',
      );
      return false;
    }
  }
}

class TrustedContactController extends RequestController {
  Future<bool> saveContact({
    required String uid,
    required String displayName,
    required String phoneNumber,
  }) async {
    if (!startRequest()) {
      return false;
    }
    try {
      await ref
          .read(userRepositoryProvider)
          .createTrustedContact(
            uid: uid,
            contact: TrustedContact(
              displayName: displayName,
              phoneNumber: phoneNumber,
            ),
          );
      ref.invalidate(trustedContactExistsProvider(uid));
      state = RequestState.idle;
      return true;
    } on Object {
      state = RequestState.error(
        'Kontak darurat belum dapat disimpan. Periksa koneksi lalu coba lagi.',
      );
      return false;
    }
  }
}

class SignOutController extends RequestController {
  Future<bool> signOut() async {
    if (!startRequest()) {
      return false;
    }
    try {
      await ref.read(authRepositoryProvider).signOut();
      state = RequestState.idle;
      return true;
    } on Object {
      state = RequestState.error(
        'Akun belum dapat dikeluarkan. Silakan coba lagi.',
      );
      return false;
    }
  }
}
