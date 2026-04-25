import 'package:url_launcher/url_launcher.dart';
import '../core/errors/app_exceptions.dart';

/// Sends SMS by opening the device's native SMS app with a pre-filled message.
/// No API key or paid service required.
class SmsService {
  SmsService._();

  static Future<void> sendSms({
    required String to,
    required String message,
  }) async {
    // Sanitise the phone number — remove spaces/dashes for the URI
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
