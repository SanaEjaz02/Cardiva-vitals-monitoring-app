import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat _time = DateFormat('HH:mm:ss');
  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, HH:mm');

  static String time(DateTime dt) => _time.format(dt);
  static String date(DateTime dt) => _date.format(dt);
  static String dateTime(DateTime dt) => _dateTime.format(dt);

  static String relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return _date.format(dt);
  }
}
