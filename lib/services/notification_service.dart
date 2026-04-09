import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fcm   = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  static const _channelId   = 'proximity_channel';
  static const _channelName = 'Nearby POI Alerts';

  Future<void> init() async {
    debugPrint('=== NotificationService.init() started ===');

    // 1. Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('=== Permission status: ${settings.authorizationStatus} ===');

    // 2. Get device token
    _fcmToken = await _fcm.getToken();
    debugPrint('=== FCM token: $_fcmToken ===');

    // Refresh token listener
    _fcm.onTokenRefresh.listen((t) {
      _fcmToken = t;
      debugPrint('=== FCM token refreshed: $t ===');
    });

    // 3. Local notifications setup
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings     = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS:     iosSettings,
      ),
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap — payload contains poi_id if set
        debugPrint('Notification tapped: ${details.payload}');
      },
    );

    // 4. Android notification channel
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Alerts when you are near a point of interest',
        importance:  Importance.high,
        playSound:   true,
      );
      await _local
          .resolvePlatformSpecificImplementation
              <AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // 5. Foreground FCM messages
    FirebaseMessaging.onMessage.listen(_showLocalFromRemote);

    // 7. Foreground presentation options (iOS)
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('=== NotificationService.init() completed ===');
  }

  // ── Show notification from FCM foreground message ─────────────────────────

  void _showLocalFromRemote(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    showLocal(
      title:   n.title ?? '',
      body:    n.body  ?? '',
      id:      message.hashCode,        // unique per message
      payload: message.data['poi_id'],  // passed through to tap handler
    );
  }

  // Show a local notification directly
  Future<void> showLocal({
    required String title,
    required String body,
    int?    id,
    String? payload,
  }) async {
    final notifId = id ?? DateTime.now().millisecondsSinceEpoch % 100000;

    await _local.show(
      notifId,
      title,
      body,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority:   Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  // ── Convenience: show a proximity alert ───────────────────────────────────
  Future<void> showProximityNotification({
    required String poiName,
    required String? poiDescription,
    required int    poiId,
    required double distanceMeters,
  }) async {
    final dist = distanceMeters < 1000
        ? '${distanceMeters.round()}m away'
        : '${(distanceMeters / 1000).toStringAsFixed(1)}km away';

    await showLocal(
      title:   "You're near $poiName!",
      body:    poiDescription != null && poiDescription.isNotEmpty
                   ? '$poiDescription • $dist'
                   : dist,
      id:      poiId,// stable per POI — replaces previous alert for same POI
      payload: poiId.toString(),
    );
  }
}