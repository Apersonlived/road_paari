import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  static const _channelId   = 'proximity_channel';
  static const _channelName = 'Nearby POI Alerts';

  Future<void> init() async {
    debugPrint('=== NotificationService.init() started ===');

    // 1. Request permission
    final settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true,
    );
    debugPrint('=== Permission status: ${settings.authorizationStatus} ===');

    // 2. Get device token
    _fcmToken = await _fcm.getToken();
    debugPrint('=== FCM token in init: $_fcmToken ===');
    _fcm.onTokenRefresh.listen((t) {
      _fcmToken = t;
      debugPrint('=== FCM token refreshed: $t ===');
    });

    // 3. Local notifications setup
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // 4. Android notification channel
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.high,
        playSound: true,
      );
      await _local
          .resolvePlatformSpecificImplementation
          <AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // 5. Foreground FCM messages
    FirebaseMessaging.onMessage.listen(_showLocalFromRemote);

    // 6. Foreground presentation options
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    debugPrint('=== NotificationService.init() completed ===');
  }

  void _showLocalFromRemote(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    showLocal(title: n.title ?? '', body: n.body ?? '');
  }

  Future<void> showLocal({
    required String title,
    required String body,
    int id = 0,
  }) async {
    await _local.show(
      id,
      title,
      body,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentSound: true,
        ),
      ),
    );
  }
}