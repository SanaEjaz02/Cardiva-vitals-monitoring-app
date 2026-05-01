import 'package:shared_preferences/shared_preferences.dart';

/// Tracks non-auth session state that Firebase cannot store — specifically
/// whether the user has already been shown the onboarding flow.
///
/// Auth tokens themselves are managed entirely by Firebase Auth, which stores
/// them in platform-native secure storage (iOS Keychain / Android
/// EncryptedSharedPreferences). No manual token handling is required.
class SessionService {
  SessionService._();

  static const _kOnboardingSeen = 'onboarding_seen';

  /// Returns true once the user has completed or skipped onboarding at least
  /// once. Used by SplashScreen to decide between /onboarding and /auth.
  static Future<bool> isOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingSeen) ?? false;
  }

  /// Call this when the user taps "Get Started" on slide 3 or "Skip" on any
  /// slide so we never show onboarding again on subsequent cold starts.
  static Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingSeen, true);
  }
}
