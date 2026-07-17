import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

import '../models/distress_session.dart';

class DistressStartResult {
  const DistressStartResult({
    required this.sessionId,
    required this.recipientCount,
    required this.recipientDisplayNames,
  });

  final String sessionId;
  final int recipientCount;
  final List<String> recipientDisplayNames;
}

class DistressRepository {
  DistressRepository.firebase()
    : _firestore = FirebaseFirestore.instance,
      _auth = FirebaseAuth.instance;

  const DistressRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<DistressStartResult> startSession(LatLng location) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const DistressDataException('Masuk ke akun Jaga terlebih dahulu.');
    }

    try {
      final senderSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      final senderDisplayName =
          senderSnapshot.data()?['displayName'] as String? ?? 'Pengguna Jaga';
      final sessionReference = _firestore.collection('distressSessions').doc();
      await sessionReference.set(<String, Object>{
        'senderUid': user.uid,
        'recipientUids': const <String>[],
        'senderDisplayName': senderDisplayName,
        'audience': 'nearby_helper',
        'status': 'active',
        'preciseLocation': GeoPoint(location.latitude, location.longitude),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 1)),
        ),
      });
      return DistressStartResult(
        sessionId: sessionReference.id,
        recipientCount: 0,
        recipientDisplayNames: const <String>[],
      );
    } on FirebaseException catch (error) {
      throw DistressDataException(_messageForFirestoreError(error));
    }
  }

  Future<void> updateLocation(String sessionId, LatLng location) async {
    try {
      await _firestore
          .collection('distressSessions')
          .doc(sessionId)
          .update(<String, Object>{
            'preciseLocation': GeoPoint(location.latitude, location.longitude),
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } on FirebaseException catch (error) {
      throw DistressDataException(_messageForFirestoreError(error));
    }
  }

  Future<void> stopSession(String sessionId) async {
    try {
      await _firestore.collection('distressSessions').doc(sessionId).update(
        <String, Object>{
          'status': 'ended',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } on FirebaseException catch (error) {
      throw DistressDataException(_messageForFirestoreError(error));
    }
  }

  Stream<DistressSession> watchSession(String sessionId) {
    return _firestore
        .collection('distressSessions')
        .doc(sessionId)
        .snapshots()
        .map(DistressSession.fromFirestore)
        .handleError((Object error) {
          if (error is FirebaseException && error.code == 'permission-denied') {
            throw const DistressDataException(
              'Kamu tidak memiliki akses ke sesi darurat ini.',
            );
          }
          throw error;
        });
  }

  String _messageForFirestoreError(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' => 'Kamu tidak diizinkan mengubah sesi darurat ini.',
      'not-found' => 'Sesi darurat tidak ditemukan.',
      'unavailable' => 'Koneksi ke layanan darurat sedang tidak tersedia.',
      _ => 'Sesi darurat belum dapat diproses. Coba lagi.',
    };
  }
}
