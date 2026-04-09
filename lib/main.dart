import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'data/api/api_client.dart';
import 'app.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final n = message.notification;
  if (n == null) return;

  final local = FlutterLocalNotificationsPlugin();
  await local.show(
    message.hashCode,
    n.title ?? '',
    n.body  ?? '',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'proximity_channel',
        'Nearby POI Alerts',
        importance: Importance.high,
        priority:   Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Init Firebase first
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Register background handler before anything else
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 3. Init API client and await token loading
  final apiClient = ApiClient();
  await apiClient.init(); // to ensure token is loaded before any request fires

  // 4. Init notifications
  await NotificationService.instance.init();

  runApp(MyApp(apiClient: apiClient)); // pass initialized client
}