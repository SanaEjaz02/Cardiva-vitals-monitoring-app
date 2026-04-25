import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/main_nav_screen.dart';

class AppRouter {
  AppRouter._();

  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home'; // MainNavScreen — hosts all 4 tabs

  static Map<String, WidgetBuilder> get routes => {
        login: (_) => const LoginScreen(),
        register: (_) => const RegisterScreen(),
        home: (_) => const MainNavScreen(),
      };
}
