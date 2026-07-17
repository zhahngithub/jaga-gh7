import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaga/core/theme/app_colors.dart';

import '../../application/profile_controllers.dart';
import '../../application/profile_providers.dart';
import '../../application/profile_validation.dart';
import '../../application/trusted_contact_policy.dart';
import '../../data/models/profile_settings.dart';
import '../../data/models/profile_trusted_contact.dart';
import '../widgets/profile_components.dart';
import '../widgets/trusted_contact_dialog.dart';

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({required this.uid, super.key});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileSettingsProvider(uid));

    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF6FF),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Profil & Pengaturan',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: profile.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (_, _) => _ProfileLoadError(
            onRetry: () => ref.invalidate(profileSettingsProvider(uid)),
          ),
          data: (data) {
            if (data == null) {
              return _ProfileLoadError(
                message: 'Profil akun tidak ditemukan.',
                onRetry: () => ref.invalidate(profileSettingsProvider(uid)),
              );
            }
            return _LoadedProfileSettings(
              profile: data,
              contacts: ref.watch(profileTrustedContactsProvider(uid)),
            );
          },
        ),
      ),
    );
  }
}

class _LoadedProfileSettings extends ConsumerStatefulWidget {
  const _LoadedProfileSettings({required this.profile, required this.contacts});

  final ProfileSettings profile;
  final AsyncValue<List<ProfileTrustedContact>> contacts;

  @override
  ConsumerState<_LoadedProfileSettings> createState() =>
      _LoadedProfileSettingsState();
}

class _LoadedProfileSettingsState
    extends ConsumerState<_LoadedProfileSettings> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.profile.displayName,
    );
    _phoneController = TextEditingController(text: widget.profile.phoneNumber);
  }

  @override
  void didUpdateWidget(covariant _LoadedProfileSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_displayNameController.text == oldWidget.profile.displayName) {
      _displayNameController.text = widget.profile.displayName;
    }
    if (_phoneController.text == oldWidget.profile.phoneNumber) {
      _phoneController.text = widget.profile.phoneNumber;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _hasProfileChanges {
    return _displayNameController.text.trim() != widget.profile.displayName ||
        _phoneController.text.trim() != widget.profile.phoneNumber;
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await ref
        .read(profileFormControllerProvider.notifier)
        .save(
          uid: widget.profile.uid,
          currentProfile: widget.profile,
          displayNameInput: _displayNameController.text,
          phoneInput: _phoneController.text,
        );
  }

  Future<void> _openContactDialog([ProfileTrustedContact? contact]) async {
    ref.read(trustedContactMutationControllerProvider.notifier).clearFeedback();
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          TrustedContactDialog(uid: widget.profile.uid, contact: contact),
    );
  }

  Future<void> _requestDelete(
    ProfileTrustedContact contact,
    List<ProfileTrustedContact> contacts,
  ) async {
    if (!canDeleteTrustedContact(contacts.length)) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: const Icon(Icons.shield_outlined, color: AppColors.primary),
          title: const Text('Kontak tetap diperlukan'),
          content: const Text(finalTrustedContactMessage),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
        title: const Text('Hapus kontak?'),
        content: Text(
          '${contact.displayName} akan dihapus dari kontak tepercaya kamu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await ref
        .read(trustedContactMutationControllerProvider.notifier)
        .delete(
          uid: widget.profile.uid,
          contactId: contact.id,
          knownContactCount: contacts.length,
        );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(profileFormControllerProvider);
    final preferenceState = ref.watch(preferenceControllerProvider);
    final contactState = ref.watch(trustedContactMutationControllerProvider);
    final helperMode =
        preferenceState.helperModeOverride ?? widget.profile.helperModeEnabled;
    final communityAssistance =
        preferenceState.communityAssistanceOverride ??
        widget.profile.communityAssistanceEnabled;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileHeader(profile: widget.profile),
              const SizedBox(height: 18),
              ProfileSectionCard(
                title: 'Informasi akun',
                icon: Icons.badge_outlined,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _displayNameController,
                        enabled: !formState.isLoading,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        validator: validateProfileDisplayName,
                        onChanged: (_) {
                          ref
                              .read(profileFormControllerProvider.notifier)
                              .clearFeedback();
                          setState(() {});
                        },
                        decoration: profileInputDecoration(
                          label: 'Nama panggilan',
                          icon: Icons.person_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        initialValue: widget.profile.email,
                        readOnly: true,
                        enableInteractiveSelection: true,
                        decoration: profileInputDecoration(
                          label: 'Email',
                          icon: Icons.alternate_email_rounded,
                          suffixIcon: const Tooltip(
                            message: 'Email tidak dapat diubah',
                            child: Icon(Icons.lock_outline_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        enabled: !formState.isLoading,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        validator: validateProfilePhone,
                        onChanged: (_) {
                          ref
                              .read(profileFormControllerProvider.notifier)
                              .clearFeedback();
                          setState(() {});
                        },
                        onFieldSubmitted: (_) => _saveProfile(),
                        decoration: profileInputDecoration(
                          label: 'Nomor telepon',
                          icon: Icons.phone_outlined,
                        ),
                      ),
                      if (formState.errorMessage != null ||
                          formState.successMessage != null) ...[
                        const SizedBox(height: 16),
                        ProfileMessage(
                          errorMessage: formState.errorMessage,
                          successMessage: formState.successMessage,
                        ),
                      ],
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: formState.isLoading || !_hasProfileChanges
                              ? null
                              : _saveProfile,
                          icon: formState.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Simpan perubahan'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ProfileSectionCard(
                title: 'Preferensi keamanan komunitas',
                icon: Icons.people_outline_rounded,
                child: Column(
                  children: [
                    _PreferenceRow(
                      title: 'Bersedia menjadi helper',
                      description:
                          'Izinkan Jaga menyimpan bahwa kamu bersedia membantu pengguna lain di sekitar.',
                      value: helperMode,
                      isLoading: preferenceState.helperModeLoading,
                      onChanged: (value) => ref
                          .read(preferenceControllerProvider.notifier)
                          .updateHelperMode(
                            uid: widget.profile.uid,
                            enabled: value,
                          ),
                    ),
                    const Divider(height: 28),
                    _PreferenceRow(
                      title: 'Bantuan dari komunitas',
                      description:
                          'Izinkan alert daruratmu dibagikan kepada helper di sekitar saat fitur perjalanan menggunakannya.',
                      value: communityAssistance,
                      isLoading: preferenceState.communityAssistanceLoading,
                      onChanged: (value) => ref
                          .read(preferenceControllerProvider.notifier)
                          .updateCommunityAssistance(
                            uid: widget.profile.uid,
                            enabled: value,
                          ),
                    ),
                    if (preferenceState.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      ProfileMessage(
                        errorMessage: preferenceState.errorMessage,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ProfileSectionCard(
                title: 'Kontak tepercaya',
                icon: Icons.contact_phone_outlined,
                action: TextButton.icon(
                  onPressed: contactState.isSubmitting
                      ? null
                      : () => _openContactDialog(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Tambah kontak'),
                ),
                child: _buildContacts(contactState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContacts(ContactMutationState request) {
    return widget.contacts.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      ),
      error: (_, _) => Column(
        children: [
          const ProfileMessage(
            errorMessage:
                'Kontak tepercaya belum dapat dimuat. Silakan coba lagi.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(
              profileTrustedContactsProvider(widget.profile.uid),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
      data: (contacts) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (request.errorMessage != null ||
              request.successMessage != null) ...[
            ProfileMessage(
              errorMessage: request.errorMessage,
              successMessage: request.successMessage,
            ),
            const SizedBox(height: 12),
          ],
          if (contacts.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FBFE),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.person_add_alt_1_outlined,
                    color: AppColors.textMuted,
                    size: 36,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Belum ada kontak tepercaya.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          else
            ...contacts.map(
              (contact) => _ContactRow(
                contact: contact,
                isDeleting: request.deletingContactId == contact.id,
                actionsEnabled: request.deletingContactId == null,
                onEdit: () => _openContactDialog(contact),
                onDelete: () => _requestDelete(contact, contacts),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final ProfileSettings profile;

  String get _initials {
    final parts = profile.displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330087FF),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white,
            child: Text(
              _initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  profile.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xDFFFFFFF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.title,
    required this.description,
    required this.value,
    required this.isLoading,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final bool isLoading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (isLoading)
          const SizedBox(
            width: 48,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.3),
              ),
            ),
          )
        else
          Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.contact,
    required this.isDeleting,
    required this.actionsEnabled,
    required this.onEdit,
    required this.onDelete,
  });

  final ProfileTrustedContact contact;
  final bool isDeleting;
  final bool actionsEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1EDF5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: const Color(0xFFE3F3FF),
            child: Text(
              contact.displayName.isEmpty
                  ? '?'
                  : contact.displayName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  contact.phoneNumber,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit kontak',
            onPressed: actionsEnabled ? onEdit : null,
            icon: const Icon(Icons.edit_outlined),
          ),
          if (isDeleting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 13),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            )
          else
            IconButton(
              tooltip: 'Hapus kontak',
              onPressed: actionsEnabled ? onDelete : null,
              color: Colors.red,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({
    required this.onRetry,
    this.message = 'Profil belum dapat dimuat. Periksa koneksi lalu coba lagi.',
  });

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ProfileSectionCard(
            title: 'Profil belum tersedia',
            icon: Icons.cloud_off_rounded,
            child: Column(
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 18),
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
    );
  }
}
