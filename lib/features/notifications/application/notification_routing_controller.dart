import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notification_messaging_repository.dart';

class NotificationNavigationState {
  const NotificationNavigationState({
    this.pendingSessionId,
    this.viewedSessionId,
    this.audience,
  });

  final String? pendingSessionId;
  final String? viewedSessionId;
  final String? audience;
}

final notificationMessagingRepositoryProvider =
    Provider<NotificationMessagingRepository>((ref) {
      final repository = NotificationMessagingRepository.firebase();
      ref.onDispose(repository.dispose);
      return repository;
    });

final notificationNavigationProvider =
    NotifierProvider<
      NotificationNavigationController,
      NotificationNavigationState
    >(NotificationNavigationController.new);

class NotificationNavigationController
    extends Notifier<NotificationNavigationState> {
  @override
  NotificationNavigationState build() => const NotificationNavigationState();

  bool handlePayload(Map<String, dynamic> data) {
    if (data['type'] != 'distress_help_request') return false;
    final sessionId = data['sessionId'];
    final audience = data['audience'];
    if (sessionId is! String || sessionId.trim().isEmpty) return false;
    if (audience != 'trusted_contact' && audience != 'nearby_helper') {
      return false;
    }
    state = NotificationNavigationState(
      pendingSessionId: sessionId.trim(),
      viewedSessionId: state.viewedSessionId,
      audience: audience as String,
    );
    return true;
  }

  void activatePendingSession() {
    final pendingSessionId = state.pendingSessionId;
    if (pendingSessionId == null) return;
    state = NotificationNavigationState(
      viewedSessionId: pendingSessionId,
      audience: state.audience,
    );
  }

  void clearViewedSession() {
    state = const NotificationNavigationState();
  }
}

final notificationCoordinatorProvider =
    NotifierProvider<NotificationCoordinator, bool>(
      NotificationCoordinator.new,
    );

class NotificationCoordinator extends Notifier<bool> {
  final List<StreamSubscription<Object?>> _subscriptions = [];
  StreamSubscription<bool>? _helperModeSubscription;
  StreamSubscription<Map<String, dynamic>>? _distressAlertSubscription;
  bool _initializing = false;

  @override
  bool build() {
    ref.onDispose(() {
      for (final subscription in _subscriptions) {
        unawaited(subscription.cancel());
      }
      unawaited(_helperModeSubscription?.cancel());
      unawaited(_distressAlertSubscription?.cancel());
    });
    return false;
  }

  Future<void> initialize() async {
    if (state || _initializing) return;
    _initializing = true;
    final repository = ref.read(notificationMessagingRepositoryProvider);
    try {
      await repository.initializeLocalNotifications();
      await repository.requestPermission();

      _subscriptions.add(repository.localNotificationOpens.listen(_route));
      _subscriptions.add(
        repository.signedInUidChanges.listen(_handleAuthenticationChange),
      );

      final initialLocalData = await repository.getInitialLocalData();
      if (initialLocalData != null) _route(initialLocalData);
      state = true;
    } on Object {
      state = false;
    } finally {
      _initializing = false;
    }
  }

  void _route(Map<String, dynamic> data) {
    ref.read(notificationNavigationProvider.notifier).handlePayload(data);
  }

  void _handleAuthenticationChange(String? uid) {
    unawaited(_helperModeSubscription?.cancel());
    unawaited(_distressAlertSubscription?.cancel());
    _helperModeSubscription = null;
    _distressAlertSubscription = null;
    if (uid == null) return;
    final alertsAfter = DateTime.now();
    final repository = ref.read(notificationMessagingRepositoryProvider);
    _helperModeSubscription = repository.watchHelperMode(uid).listen((enabled) {
      unawaited(_distressAlertSubscription?.cancel());
      _distressAlertSubscription = null;
      if (!enabled || repository.currentUid != uid) return;
      _distressAlertSubscription = repository
          .watchNewDistressAlerts(uid: uid, after: alertsAfter)
          .listen((data) {
            unawaited(repository.showLocalDistressAlert(data));
          });
    });
  }
}
