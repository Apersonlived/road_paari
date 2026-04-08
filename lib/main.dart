import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'app.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  try {
    await NotificationService.instance.init();
    debugPrint('=== 4: INIT SUCCESS: ${NotificationService.instance.fcmToken} ===');
  } catch (e, stack) {
    debugPrint('=== 4: INIT FAILED: $e ===');
    debugPrint('=== STACK: $stack ===');
  }

  debugPrint('=== 5: calling runApp ===');
  runApp(const MyApp());
}