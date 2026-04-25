class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => 'AppException: $message${code != null ? ' (code: $code)' : ''}';
}

class CloudException extends AppException {
  const CloudException(super.message, {super.code});
}

class LocationException extends AppException {
  const LocationException(super.message, {super.code});
}

class SmsException extends AppException {
  const SmsException(super.message, {super.code});
}

class BleException extends AppException {
  const BleException(super.message, {super.code});
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}
