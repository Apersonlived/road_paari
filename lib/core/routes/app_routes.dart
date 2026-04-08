import 'package:flutter/material.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/signup_screen.dart';
import '../../presentation/screens/map/map_screen.dart';
import '../../presentation/screens/poi/explore.dart';
import '../../presentation/screens/poi/update.dart';
import '../../presentation/screens/profile/profile.dart';

class AppRoutes {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String map = '/map';
  static const String explore = '/explore';
  static const String updates = '/updates';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginScreen(),
    signup: (context) => const SignUpScreen(),
    map: (context) => const MapScreen(),
    updates: (context) => const UpdatesScreen(),
    profile: (context) => const ProfileScreen(),
    explore: (context) => const ExploreScreen()
  };
}