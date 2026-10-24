import 'package:flutter_test/flutter_test.dart';

import 'package:chai_tapri/core/daily.dart';

void main() {
  group('dateKey', () {
    test('formats the local calendar day', () {
      expect(dateKey(DateTime(2026, 10, 22)), '2026-10-22');
      expect(dateKey(DateTime(2026, 1, 5, 23, 59, 59)), '2026-01-05');
      expect(dateKey(DateTime(2027, 12, 31)), '2027-12-31');
    });

    test('pads short years', () {
      expect(dateKey(DateTime(987, 3, 4)), '0987-03-04');
    });
  });

  group('parseDateKey', () {
    test('reads a valid key', () {
      final DateTime? date = parseDateKey('2026-10-22');
      expect(date, isNotNull);
      expect(date!.year, 2026);
      expect(date.month, 10);
      expect(date.day, 22);
      expect(date.isUtc, isTrue);
    });

    test('rejects malformed keys', () {
      for (final String key in <String>[
        '',
        '2026-1-1',
        '26-10-22',
        '2026-13-01',
        '2026-00-10',
        '2026-10-00',
        '2026-10-32',
        'abcd-ef-gh',
        '2026-10-22x',
        ' 2026-10-22',
        '2026/10/22',
      ]) {
        expect(parseDateKey(key), isNull, reason: key);
      }
    });
  });

  group('daysBetween', () {
    test('counts calendar days', () {
      expect(daysBetween('2026-10-22', '2026-10-22'), 0);
      expect(daysBetween('2026-10-22', '2026-10-23'), 1);
      expect(daysBetween('2026-10-22', '2026-10-25'), 3);
      expect(daysBetween('2026-10-23', '2026-10-22'), -1);
    });

    test('crosses month, year and leap-day boundaries', () {
      expect(daysBetween('2026-10-31', '2026-11-01'), 1);
      expect(daysBetween('2026-12-31', '2027-01-01'), 1);
      expect(daysBetween('2027-02-28', '2027-03-01'), 1);
      expect(daysBetween('2028-02-28', '2028-03-01'), 2);
      expect(daysBetween('2026-01-01', '2027-01-01'), 365);
      expect(daysBetween('2028-01-01', '2029-01-01'), 366);
    });

    test('is not shifted by daylight saving changes', () {
      // Whatever the time zone, the difference is computed on UTC midnights.
      expect(daysBetween('2026-03-28', '2026-03-29'), 1);
      expect(daysBetween('2026-03-29', '2026-03-30'), 1);
      expect(daysBetween('2026-10-24', '2026-10-25'), 1);
      expect(daysBetween('2026-10-25', '2026-10-26'), 1);
    });

    test('returns null for malformed keys', () {
      expect(daysBetween('', '2026-10-22'), isNull);
      expect(daysBetween('2026-10-22', 'tomorrow'), isNull);
    });
  });
}
