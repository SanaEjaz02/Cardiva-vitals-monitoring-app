import 'package:url_launcher/url_launcher.dart';
import '../core/errors/app_exceptions.dart';

class SmsService {
  SmsService._();

  static String _e164Digits(String raw) =>
      raw.replaceAll(RegExp(r'[^\d]'), '');

  /// Sends via WhatsApp only (does NOT fall back to SMS).
  static Future<void> sendWhatsApp({
    required String to,
    required String message,
  }) async {
    final digits = _e164Digits(to);
    if (digits.isEmpty) return;
    final waUri = Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens the native SMS app with [phones] in the recipient field
  /// and [message] pre-filled. Recipient list joined by ';'.
  static Future<void> sendSmsToAll({
    required List<String> phones,
    required String message,
  }) async {
    if (phones.isEmpty) return;
    final cleaned = phones
        .map((p) => p.replaceAll(RegExp(r'[\s\-()]'), ''))
        .where((p) => p.isNotEmpty)
        .toList();
    // Android uses comma-separated numbers; iOS uses semicolons.
    // We try comma first (RFC 5724 / most Android SMS apps).
    final recipients = cleaned.join(',');
    final uri = Uri(
      scheme: 'sms',
      path: recipients,
      queryParameters: {'body': message},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw const SmsException(
        'Could not launch SMS app. '
        'Ensure the sms: scheme is supported on this device.',
      );
    }
  }

  /// Legacy single-contact helper kept for compatibility.
  static Future<void> sendAlert({
    required String to,
    required String message,
  }) => sendSms(to: to, message: message);

  static Future<void> sendSms({
    required String to,
    required String message,
  }) => sendSmsToAll(phones: [to], message: message);
}
