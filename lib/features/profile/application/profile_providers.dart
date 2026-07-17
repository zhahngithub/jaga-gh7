import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/models/profile_settings.dart';
import '../data/models/profile_trusted_contact.dart';
import '../data/repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(firebaseFirestoreProvider));
});

final profileSettingsProvider = StreamProvider.family<ProfileSettings?, String>(
  (ref, uid) {
    return ref.watch(profileRepositoryProvider).watchProfile(uid);
  },
);

final profileTrustedContactsProvider =
    StreamProvider.family<List<ProfileTrustedContact>, String>((ref, uid) {
      return ref.watch(profileRepositoryProvider).watchTrustedContacts(uid);
    });
