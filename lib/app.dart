import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'data/api/api_client.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/repositories/poi_repository.dart';
import 'data/repositories/notif_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/map_provider.dart';
import 'providers/location_provider.dart';
import 'providers/poi_provider.dart';
import 'providers/notification_provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();

    return MultiProvider(
      providers: [
        // Infrastructure for API calls
        Provider<ApiClient>(create: (_) => apiClient),
        Provider<AuthRepository>(create: (_) => AuthRepository(apiClient)),
        Provider<UserRepository>(create: (_) => UserRepository(apiClient)),
        Provider<POIRepository>(create: (context) => POIRepository(apiClient)),
        Provider<NotificationRepository>(
          create: (_) => NotificationRepository(apiClient),
        ),

        // Auth uses two repositories: user and authentication
        ChangeNotifierProxyProvider2<
          AuthRepository,
          UserRepository,
          AuthProvider
        >(
          create: (_) => AuthProvider(
            authRepository: AuthRepository(apiClient),
            userRepository: UserRepository(apiClient),
          ),
          update: (_, authRepo, userRepo, previous) =>
              previous ??
              AuthProvider(authRepository: authRepo, userRepository: userRepo),
        ),

        // Map & Location
        ChangeNotifierProvider(
          create: (context) => MapProvider(apiClient: apiClient),
        ),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProxyProvider<POIRepository, POIProvider>(
          create: (_) => POIProvider(repository: POIRepository(apiClient)),
          update: (_, repo, previous) =>
              previous ?? POIProvider(repository: repo),
        ),

        // Notification
        ChangeNotifierProxyProvider<NotificationRepository, NotificationProvider>(
          create: (_) => NotificationProvider(
            repository: NotificationRepository(apiClient),
          ),
          update: (_, repo, previous) =>
              previous ?? NotificationProvider(repository: repo),
        )
      ],
      child: MaterialApp(
        title: 'RoadPaari',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: AppRoutes.login,
        routes: AppRoutes.routes,
      ),
    );
  }
}
