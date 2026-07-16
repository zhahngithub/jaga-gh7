import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trusted_contact.dart';
import '../models/user_profile.dart';

class UserRepository {
  const UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<UserProfile?> getUserProfile(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }
    return UserProfile.fromMap(uid: uid, map: data);
  }

  Future<void> createUserProfile(UserProfile profile) {
    final serverTimestamp = FieldValue.serverTimestamp();
    return _firestore
        .collection('users')
        .doc(profile.uid)
        .set(
          profile.toMap(createdAt: serverTimestamp, updatedAt: serverTimestamp),
        );
  }

  Future<bool> hasTrustedContact(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('trustedContacts')
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> createTrustedContact({
    required String uid,
    required TrustedContact contact,
  }) {
    final reference = _firestore
        .collection('users')
        .doc(uid)
        .collection('trustedContacts')
        .doc();
    return reference.set(
      contact.toMap(createdAt: FieldValue.serverTimestamp()),
    );
  }
}
