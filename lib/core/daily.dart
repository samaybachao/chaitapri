/// Local-date helpers for the daily reward.
///
/// Dates are stored as `yyyy-MM-dd` strings of the player's LOCAL calendar day.
/// Day differences are computed on UTC midnights, so daylight-saving changes
/// can never shift a day.
library;

final RegExp _dateKeyPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// `2026-10-22` for the local calendar day of [local].
String dateKey(DateTime local) {
  final String year = local.year.toString().padLeft(4, '0');
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Parses a key made by [dateKey]; null when [key] is malformed.
DateTime? parseDateKey(String key) {
  final RegExpMatch? match = _dateKeyPattern.firstMatch(key);
  if (match == null) {
    return null;
  }
  final int? year = int.tryParse(match.group(1) ?? '');
  final int? month = int.tryParse(match.group(2) ?? '');
  final int? day = int.tryParse(match.group(3) ?? '');
  if (year == null || month == null || day == null) {
    return null;
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  return DateTime.utc(year, month, day);
}

/// Whole calendar days from [from] to [to] (negative when [to] is earlier).
/// Returns null when either key is malformed.
int? daysBetween(String from, String to) {
  final DateTime? start = parseDateKey(from);
  final DateTime? end = parseDateKey(to);
  if (start == null || end == null) {
    return null;
  }
  return end.difference(start).inDays;
}
