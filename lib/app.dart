import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'data/api/api_client.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/user_repository.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/map_provider.dart';
import 'presentation/providers/location_provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();

    return MultiProvider(
      providers: [
        // Infrastructure for API calls
        Provider<ApiClient>(
          create: (_) => apiClient,
        ),
        Provider<AuthRepository>(
          create: (_) => AuthRepository(apiClient),
        ),
        Provider<UserRepository>(
          create: (_) => UserRepository(apiClient),
        ),

        // Auth uses two repositories: user and authentication
        ChangeNotifierProxyProvider2<AuthRepository, UserRepository,
            AuthProvider>(
          create: (_) => AuthProvider(
            authRepository: AuthRepository(apiClient),
            userRepository: UserRepository(apiClient),
          ),
          update: (_, authRepo, userRepo, previous) =>
              previous ?? AuthProvider(
                authRepository: authRepo,
                userRepository: userRepo,
              ),
        ),

        // Map & Location
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
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