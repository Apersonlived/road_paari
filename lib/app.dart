import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/proximity_service.dart';
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
  final ApiClient apiClient; // ← accept it
  const MyApp({super.key, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Infrastructure
        Provider<ApiClient>(create: (_) => apiClient),
        Provider<AuthRepository>(create: (_) => AuthRepository(apiClient)),
        Provider<UserRepository>(create: (_) => UserRepository(apiClient)),
        Provider<POIRepository>(create: (_) => POIRepository(apiClient)),
        Provider<NotificationRepository>(
          create: (_) => NotificationRepository(apiClient),
        ),

        // ── Move LocationProvider UP here, before AuthProvider ──
        ChangeNotifierProvider(create: (_) => LocationProvider()),

        // Auth — can now safely read LocationProvider
        ChangeNotifierProxyProvider2<
          AuthRepository,
          UserRepository,
          AuthProvider
        >(
          create: (context) => AuthProvider(
            authRepository: AuthRepository(apiClient),
            userRepository: UserRepository(apiClient),
            proximityService: ProximityService(
              locationProvider: context
                  .read<LocationProvider>(), // ← now available
              notificationRepository: context.read<NotificationRepository>(),
            ),
          ),
          update: (context, authRepo, userRepo, previous) =>
              previous ??
              AuthProvider(
                authRepository: authRepo,
                userRepository: userRepo,
                proximityService: ProximityService(
                  locationProvider: context.read<LocationProvider>(),
                  notificationRepository: context
                      .read<NotificationRepository>(),
                ),
              ),
        ),

        // Map & Location — LocationProvider already registered above, don't add again
        ChangeNotifierProvider(
          create: (_) => MapProvider(apiClient: apiClient),
        ),

        ChangeNotifierProxyProvider<POIRepository, POIProvider>(
          create: (_) => POIProvider(repository: POIRepository(apiClient)),
          update: (_, repo, previous) =>
              previous ?? POIProvider(repository: repo),
        ),

        ChangeNotifierProxyProvider<
          NotificationRepository,
          NotificationProvider
        >(
          create: (_) => NotificationProvider(
            repository: NotificationRepository(apiClient),
          ),
          update: (_, repo, previous) =>
              previous ?? NotificationProvider(repository: repo),
        ),
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
