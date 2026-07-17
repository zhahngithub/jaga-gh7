import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationMessagingRepository {
  NotificationMessagingRepository.firebase()
    : _auth = FirebaseAuth.instance,
      _firestore = FirebaseFirestore.instance,
      _localNotifications = FlutterLocalNotificationsPlugin();

  NotificationMessagingRepository(
    this._auth,
    this._firestore,
    this._localNotifications,
  );

  static const String distressChannelId = 'jaga_distress_alerts';
  static const String distressChannelName = 'Permintaan bantuan darurat';
  static const String distressChannelDescription =
      'Notifikasi permintaan bantuan dari kontak tepercaya Jaga.';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final StreamController<Map<String, dynamic>> _localNotificationOpens =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get localNotificationOpens =>
      _localNotificationOpens.stream;

  Stream<String?> get signedInUidChanges =>
      _auth.authStateChanges().map((user) => user?.uid);

  String? get currentUid => _auth.currentUser?.uid;

  Stream<bool> watchHelperMode(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.data()?['helperModeEnabled'] == true)
        .distinct();
  }

  Stream<Map<String, dynamic>> watchNewNearbyHelperAlerts({
    required String uid,
    required DateTime after,
  }) {
    return _watchNewDistressAlerts(
      query: _firestore
          .collection('distressSessions')
          .where('audience', isEqualTo: 'nearby_helper'),
      uid: uid,
      after: after,
      audience: 'nearby_helper',
    );
  }

  Stream<Map<String, dynamic>> watchNewTrustedContactAlerts({
    required String uid,
    required DateTime after,
  }) async* {
    final userSnapshot = await _firestore.collection('users').doc(uid).get();
    final phoneNumber = (userSnapshot.data()?['phoneNumber'] as String?)
        ?.trim();
    if (phoneNumber == null || phoneNumber.isEmpty) return;

    yield* _watchNewDistressAlerts(
      query: _firestore
          .collection('distressSessions')
          .where('recipientPhoneNumbers', arrayContains: phoneNumber),
      uid: uid,
      after: after,
      audience: 'trusted_contact',
      trustedRecipientPhone: phoneNumber,
    );
  }

  Stream<Map<String, dynamic>> _watchNewDistressAlerts({
    required Query<Map<String, dynamic>> query,
    required String uid,
    required DateTime after,
    required String audience,
    String? trustedRecipientPhone,
  }) {
    return query
        .snapshots()
        .expand((snapshot) => snapshot.docChanges)
        .where((change) {
          if (change.type != DocumentChangeType.added) return false;
          final data = change.doc.data();
          if (data == null || data['status'] != 'active') return false;
          if (data['audience'] != audience) return false;
          if (data['senderUid'] == uid) return false;
          final createdAt = data['createdAt'];
          if (createdAt is! Timestamp || createdAt.toDate().isBefore(after)) {
            return false;
          }
          if (audience == 'trusted_contact') {
            final recipients = data['recipientPhoneNumbers'];
            if (trustedRecipientPhone == null ||
                recipients is! List ||
                !recipients.contains(trustedRecipientPhone)) {
              return false;
            }
          }
          final expiresAt = data['expiresAt'];
          return expiresAt is! Timestamp ||
              expiresAt.toDate().isAfter(DateTime.now());
        })
        .map((change) {
          final data = change.doc.data()!;
          return <String, dynamic>{
            'type': 'distress_help_request',
            'sessionId': change.doc.id,
            'senderUid': data['senderUid'],
            'senderDisplayName': data['senderDisplayName'],
            'audience': audience,
          };
        });
  }

  Future<void> initializeLocalNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final data = _decodePayload(response.payload);
        if (data != null) _localNotificationOpens.add(data);
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            distressChannelId,
            distressChannelName,
            description: distressChannelDescription,
            importance: Importance.max,
          ),
        );
  }

  Future<void> requestPermission() async {
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> showLocalDistressAlert(Map<String, dynamic> data) async {
    final senderDisplayName = data['senderDisplayName'] as String?;
    final isTrustedContact = data['audience'] == 'trusted_contact';
    final title = isTrustedContact
        ? 'Kontak darurat membutuhkan bantuan'
        : 'Permintaan bantuan darurat';
    final hasSenderName =
        senderDisplayName != null && senderDisplayName.isNotEmpty;
    final body = isTrustedContact
        ? hasSenderName
              ? '$senderDisplayName mengirim sinyal darurat. Ketuk untuk melihat lokasi langsung.'
              : 'Kontak darurat mengirim sinyal. Ketuk untuk melihat lokasi langsung.'
        : hasSenderName
        ? '$senderDisplayName mengirim sinyal darurat. Ketuk untuk melihat lokasi.'
        : 'Seorang pengguna Jaga mengirim sinyal darurat.';
    await _localNotifications.show(
      id:
          (data['sessionId'] as String?)?.hashCode ??
          DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          distressChannelId,
          distressChannelName,
          channelDescription: distressChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  Future<Map<String, dynamic>?> getInitialLocalData() async {
    final details = await _localNotifications.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return _decodePayload(details?.notificationResponse?.payload);
  }

  Map<String, dynamic>? _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      return null;
    }
    return null;
  }

  Future<void> dispose() => _localNotificationOpens.close();
}
