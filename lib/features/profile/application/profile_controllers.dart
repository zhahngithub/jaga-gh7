import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/models/profile_settings.dart';
import '../data/repositories/profile_repository.dart';
import 'profile_providers.dart';
import 'profile_validation.dart';
import 'trusted_contact_policy.dart';

final profileFormControllerProvider =
    NotifierProvider<ProfileFormController, ProfileFormState>(
      ProfileFormController.new,
    );

final preferenceControllerProvider =
    NotifierProvider<PreferenceController, PreferenceUpdateState>(
      PreferenceController.new,
    );

final trustedContactMutationControllerProvider =
    NotifierProvider<TrustedContactMutationController, ContactMutationState>(
      TrustedContactMutationController.new,
    );

class ProfileFormState {
  const ProfileFormState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
}

class ProfileFormController extends Notifier<ProfileFormState> {
  @override
  ProfileFormState build() => const ProfileFormState();

  Future<bool> save({
    required String uid,
    required ProfileSettings currentProfile,
    required String displayNameInput,
    required String phoneInput,
  }) async {
    if (state.isLoading) {
      return false;
    }

    final displayNameError = validateProfileDisplayName(displayNameInput);
    final normalizedPhone = normalizeProfilePhone(phoneInput);
    if (displayNameError != null || normalizedPhone == null) {
      state = const ProfileFormState(
        errorMessage: 'Periksa kembali data profil yang kamu masukkan.',
      );
      return false;
    }

    final displayName = displayNameInput.trim();
    final changedDisplayName = displayName != currentProfile.displayName;
    final changedPhone = normalizedPhone != currentProfile.phoneNumber;
    if (!changedDisplayName && !changedPhone) {
      state = const ProfileFormState(
        successMessage: 'Tidak ada perubahan yang perlu disimpan.',
      );
      return true;
    }

    state = const ProfileFormState(isLoading: true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            uid: uid,
            displayName: changedDisplayName ? displayName : null,
            phoneNumber: changedPhone ? normalizedPhone : null,
          );
      ref.invalidate(currentUserProfileProvider(uid));
      state = const ProfileFormState(
        successMessage: 'Perubahan profil berhasil disimpan.',
      );
      return true;
    } on Object {
      state = const ProfileFormState(
        errorMessage:
            'Profil belum dapat diperbarui. Periksa koneksi lalu coba lagi.',
      );
      return false;
    }
  }

  void clearFeedback() {
    if (!state.isLoading) {
      state = const ProfileFormState();
    }
  }
}

const _unchanged = Object();

class PreferenceUpdateState {
  const PreferenceUpdateState({
    this.helperModeLoading = false,
    this.communityAssistanceLoading = false,
    this.helperModeOverride,
    this.communityAssistanceOverride,
    this.errorMessage,
  });

  final bool helperModeLoading;
  final bool communityAssistanceLoading;
  final bool? helperModeOverride;
  final bool? communityAssistanceOverride;
  final String? errorMessage;

  PreferenceUpdateState copyWith({
    bool? helperModeLoading,
    bool? communityAssistanceLoading,
    Object? helperModeOverride = _unchanged,
    Object? communityAssistanceOverride = _unchanged,
    Object? errorMessage = _unchanged,
  }) {
    return PreferenceUpdateState(
      helperModeLoading: helperModeLoading ?? this.helperModeLoading,
      communityAssistanceLoading:
          communityAssistanceLoading ?? this.communityAssistanceLoading,
      helperModeOverride: identical(helperModeOverride, _unchanged)
          ? this.helperModeOverride
          : helperModeOverride as bool?,
      communityAssistanceOverride:
          identical(communityAssistanceOverride, _unchanged)
          ? this.communityAssistanceOverride
          : communityAssistanceOverride as bool?,
      errorMessage: identical(errorMessage, _unchanged)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class PreferenceController extends Notifier<PreferenceUpdateState> {
  @override
  PreferenceUpdateState build() => const PreferenceUpdateState();

  Future<void> updateHelperMode({
    required String uid,
    required bool enabled,
  }) async {
    if (state.helperModeLoading) {
      return;
    }
    state = state.copyWith(
      helperModeLoading: true,
      helperModeOverride: enabled,
      errorMessage: null,
    );
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateHelperMode(uid: uid, enabled: enabled);
      state = state.copyWith(
        helperModeLoading: false,
        helperModeOverride: null,
      );
      ref.invalidate(currentUserProfileProvider(uid));
    } on Object {
      state = state.copyWith(
        helperModeLoading: false,
        helperModeOverride: null,
        errorMessage:
            'Preferensi helper belum dapat diperbarui. Silakan coba lagi.',
      );
    }
  }

  Future<void> updateCommunityAssistance({
    required String uid,
    required bool enabled,
  }) async {
    if (state.communityAssistanceLoading) {
      return;
    }
    state = state.copyWith(
      communityAssistanceLoading: true,
      communityAssistanceOverride: enabled,
      errorMessage: null,
    );
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateCommunityAssistance(uid: uid, enabled: enabled);
      state = state.copyWith(
        communityAssistanceLoading: false,
        communityAssistanceOverride: null,
      );
      ref.invalidate(currentUserProfileProvider(uid));
    } on Object {
      state = state.copyWith(
        communityAssistanceLoading: false,
        communityAssistanceOverride: null,
        errorMessage:
            'Preferensi bantuan komunitas belum dapat diperbarui. Silakan coba lagi.',
      );
    }
  }
}

class ContactMutationState {
  const ContactMutationState({
    this.isSubmitting = false,
    this.deletingContactId,
    this.errorMessage,
    this.successMessage,
  });

  final bool isSubmitting;
  final String? deletingContactId;
  final String? errorMessage;
  final String? successMessage;
}

class TrustedContactMutationController extends Notifier<ContactMutationState> {
  @override
  ContactMutationState build() => const ContactMutationState();

  Future<bool> create({
    required String uid,
    required String displayNameInput,
    required String phoneInput,
  }) async {
    return _submitContact(
      uid: uid,
      displayNameInput: displayNameInput,
      phoneInput: phoneInput,
    );
  }

  Future<bool> update({
    required String uid,
    required String contactId,
    required String displayNameInput,
    required String phoneInput,
  }) async {
    return _submitContact(
      uid: uid,
      contactId: contactId,
      displayNameInput: displayNameInput,
      phoneInput: phoneInput,
    );
  }

  Future<bool> delete({
    required String uid,
    required String contactId,
    required int knownContactCount,
  }) async {
    if (state.deletingContactId != null) {
      return false;
    }
    if (!canDeleteTrustedContact(knownContactCount)) {
      state = const ContactMutationState(
        errorMessage: finalTrustedContactMessage,
      );
      return false;
    }

    state = ContactMutationState(deletingContactId: contactId);
    try {
      await ref
          .read(profileRepositoryProvider)
          .deleteTrustedContact(uid: uid, contactId: contactId);
      state = const ContactMutationState(
        successMessage: 'Kontak tepercaya berhasil dihapus.',
      );
      return true;
    } on FinalTrustedContactException {
      state = const ContactMutationState(
        errorMessage: finalTrustedContactMessage,
      );
      return false;
    } on Object {
      state = const ContactMutationState(
        errorMessage:
            'Kontak tepercaya belum dapat dihapus. Silakan coba lagi.',
      );
      return false;
    }
  }

  Future<bool> _submitContact({
    required String uid,
    required String displayNameInput,
    required String phoneInput,
    String? contactId,
  }) async {
    if (state.isSubmitting) {
      return false;
    }
    final nameError = validateTrustedContactName(displayNameInput);
    final phoneNumber = normalizeProfilePhone(phoneInput);
    if (nameError != null || phoneNumber == null) {
      state = const ContactMutationState(
        errorMessage: 'Periksa kembali data kontak yang kamu masukkan.',
      );
      return false;
    }

    state = const ContactMutationState(isSubmitting: true);
    try {
      final repository = ref.read(profileRepositoryProvider);
      if (contactId == null) {
        await repository.createTrustedContact(
          uid: uid,
          displayName: displayNameInput.trim(),
          phoneNumber: phoneNumber,
        );
      } else {
        await repository.updateTrustedContact(
          uid: uid,
          contactId: contactId,
          displayName: displayNameInput.trim(),
          phoneNumber: phoneNumber,
        );
      }
      state = ContactMutationState(
        successMessage: contactId == null
            ? 'Kontak tepercaya berhasil ditambahkan.'
            : 'Kontak tepercaya berhasil diperbarui.',
      );
      return true;
    } on Object {
      state = const ContactMutationState(
        errorMessage:
            'Kontak tepercaya belum dapat disimpan. Periksa koneksi lalu coba lagi.',
      );
      return false;
    }
  }

  void clearFeedback() {
    if (!state.isSubmitting && state.deletingContactId == null) {
      state = const ContactMutationState();
    }
  }
}
