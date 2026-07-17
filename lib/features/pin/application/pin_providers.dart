import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/repositories/pin_repository.dart';
import '../data/repositories/secure_key_value_store.dart';

final secureKeyValueStoreProvider = Provider<SecureKeyValueStore>((ref) {
  return FlutterSecureKeyValueStore();
});

final pinRepositoryProvider = Provider<PinRepository>((ref) {
  return LocalPinRepository(ref.watch(secureKeyValueStoreProvider));
});

final pinStatusProvider = FutureProvider.family<bool, String>((ref, uid) {
  return ref.watch(pinRepositoryProvider).hasPin(uid);
});

final currentPinUserIdProvider = Provider<String?>((ref) {
  return ref.watch(firebaseAuthProvider).currentUser?.uid;
});
