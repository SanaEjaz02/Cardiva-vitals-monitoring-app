import 'package:url_launcher/url_launcher.dart';
import '../core/errors/app_exceptions.dart';

class SmsService {
  SmsService._();

  /// Strips a phone number down to digits only (E.164 without the '+').
  /// E.g. "+92-333-1234567" → "923331234567"
  static String _e164Digits(String raw) =>
      raw.replaceAll(RegExp(r'[^\d]'), '');

  /// Tries WhatsApp first, falls back to native SMS.
  /// WhatsApp requires digits-only E.164 (no '+'), e.g. "923331234567".
  static Future<void> sendAlert({
    required String to,
    required String message,
  }) async {
    final digits = _e164Digits(to);

    // Try WhatsApp
    if (digits.isNotEmpty) {
      final waUri = Uri.parse(
        'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
      );
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // Fall back to native SMS
    await sendSms(to: to, message: message);
  }

  /// Native SMS (sms: scheme) — opens the device's SMS app.
  static Future<void> sendSms({
    required String to,
    required String message,
  }) async {
    final phone = to.replaceAll(RegExp(r'[\s\-()]'), '');
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw SmsException(
        'Could not launch SMS app for $to. '
        'Ensure the sms: scheme is supported on this device.',
      );
    }
  }
}
