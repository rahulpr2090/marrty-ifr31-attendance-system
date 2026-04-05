// lib/core/utils/date_utils.dart
// IST date/time helpers
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'package:intl/intl.dart';

class IstUtils {
  IstUtils._();

  /// Now in IST
  static DateTime now() =>
      DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

  /// Format: "dd MMM yyyy" e.g. "04 Apr 2026"
  static String formatDate(DateTime dt) =>
      DateFormat('dd MMM yyyy').format(dt.toLocal());

  /// Format: "hh:mm a" e.g. "09:30 AM"
  static String formatTime(DateTime dt) =>
      DateFormat('hh:mm a').format(dt.toLocal());

  /// Format: "dd MMM yyyy, hh:mm a"
  static String formatDateTime(DateTime dt) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());

  /// Format: "EEEE, dd MMMM yyyy" e.g. "Friday, 04 April 2026"
  static String formatDateLong(DateTime dt) =>
      DateFormat('EEEE, dd MMMM yyyy').format(dt.toLocal());

  /// Greeting based on IST hour
  static String getGreeting(String name) {
    final h = now().hour;
    if (h < 12) return 'Good Morning, $name 👋';
    if (h < 17) return 'Good Afternoon, $name 👋';
    return 'Good Evening, $name 👋';
  }

  /// Today as "YYYY-MM-DD" (IST)
  static String todayIso() {
    final n = now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Parse ISO8601 string to DateTime (assumes IST if no offset)
  static DateTime parse(String s) {
    try {
      return DateTime.parse(s).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }
}
