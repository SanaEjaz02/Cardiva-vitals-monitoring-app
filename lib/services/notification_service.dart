/// Stub NotificationService — flutter_local_notifications removed to avoid
/// network-blocked Gradle dependency (bundletool 1.9.0). Re-enable by adding
/// flutter_local_notifications back to pubspec once network access is available.
class NotificationService {
  NotificationService._();

  static Future<void> initialize() async {}

  static Future<void> showEmergencyNotification(
    String title,
    String body,
  ) async {}

  static Future<void> showWarningNotification(
    String title,
    String body,
  ) async {}
}