import 'package:flutter_test/flutter_test.dart';

import 'package:chai_tapri/core/formatting.dart';

void main() {
  group('formatNumber', () {
    test('small numbers are whole', () {
      expect(formatNumber(0), '0');
      expect(formatNumber(0.9), '0');
      expect(formatNumber(1), '1');
      expect(formatNumber(10.7), '10');
      expect(formatNumber(999.9), '999');
    });

    test('thousands and above use short suffixes', () {
      expect(formatNumber(1000), '1K');
      expect(formatNumber(1234), '1.23K');
      expect(formatNumber(1500), '1.5K');
      expect(formatNumber(12345), '12.3K');
      expect(formatNumber(123456), '123K');
      expect(formatNumber(1500000), '1.5M');
      expect(formatNumber(2.5e9), '2.5B');
      expect(formatNumber(1e12), '1T');
      expect(formatNumber(1e15), '1Qa');
      expect(formatNumber(7.77e18), '7.77Qi');
      expect(formatNumber(1e33), '1Dc');
    });

    test('rounding up rolls over to the next suffix', () {
      expect(formatNumber(999950), '1M');
      expect(formatNumber(999999), '1M');
      expect(formatNumber(999499), '999K');
      expect(formatNumber(9999), '10K');
      expect(formatNumber(99999), '100K');
    });

    test('huge numbers stay readable and never throw', () {
      expect(formatNumber(1e40), endsWith('Dc'));
      expect(formatNumber(1.7976931348623157e308), endsWith('Dc'));
    });

    test('invalid numbers show zero', () {
      expect(formatNumber(double.nan), '0');
      expect(formatNumber(double.infinity), '0');
      expect(formatNumber(double.negativeInfinity), '0');
      expect(formatNumber(-5), '0');
    });
  });

  group('formatRate', () {
    test('uses more decimals for small rates', () {
      expect(formatRate(0.6065764953290278), '0.61');
      expect(formatRate(0.05), '0.05');
      expect(formatRate(0.004), '0');
      expect(formatRate(3.2268), '3.2');
      expect(formatRate(6.337731852266973), '6.3');
      expect(formatRate(45.23), '45.2');
      expect(formatRate(99.96), '100');
    });

    test('large rates use suffixes', () {
      expect(formatRate(460), '460');
      expect(formatRate(1234), '1.23K');
      expect(formatRate(14481.116), '14.5K');
    });

    test('invalid or empty rates show zero', () {
      expect(formatRate(0), '0');
      expect(formatRate(-1), '0');
      expect(formatRate(double.nan), '0');
      expect(formatRate(double.infinity), '0');
    });
  });

  group('formatFactor', () {
    test('trims useless zeros', () {
      expect(formatFactor(1.0), '1');
      expect(formatFactor(1.2), '1.2');
      expect(formatFactor(14.5), '14.5');
      expect(formatFactor(44.0), '44');
      expect(formatFactor(0.5), '0.5');
      expect(formatFactor(120.4), '120');
      expect(formatFactor(9.999), '10');
    });

    test('invalid numbers show zero', () {
      expect(formatFactor(double.nan), '0');
      expect(formatFactor(double.infinity), '0');
    });
  });

  group('formatPercent', () {
    test('turns a fraction into a whole percent', () {
      expect(formatPercent(0.25), '25');
      expect(formatPercent(0.5), '50');
      expect(formatPercent(0.61), '61');
      expect(formatPercent(1.0), '100');
    });

    test('invalid or empty fractions show zero', () {
      expect(formatPercent(0), '0');
      expect(formatPercent(-0.3), '0');
      expect(formatPercent(double.nan), '0');
    });
  });

  group('formatDuration', () {
    test('picks the two biggest units', () {
      expect(formatDuration(0), '0s');
      expect(formatDuration(45), '45s');
      expect(formatDuration(59.9), '59s');
      expect(formatDuration(90), '1m 30s');
      expect(formatDuration(300), '5m');
      expect(formatDuration(3600), '1h');
      expect(formatDuration(8100), '2h 15m');
      expect(formatDuration(10800), '3h');
      expect(formatDuration(3725), '1h 2m');
    });

    test('the unit texts can be translated', () {
      expect(
        formatDuration(3725, hourUnit: 'hr', minuteUnit: 'min', secondUnit: 'sec'),
        '1hr 2min',
      );
      expect(formatDuration(75, minuteUnit: ' मि', secondUnit: ' से'), '1 मि 15 से');
    });

    test('invalid or negative time shows zero', () {
      expect(formatDuration(-10), '0s');
      expect(formatDuration(double.nan), '0s');
      expect(formatDuration(double.infinity), '0s');
    });
  });

  group('formatClock', () {
    test('counts down as m:ss', () {
      expect(formatClock(272), '4:32');
      expect(formatClock(300), '5:00');
      expect(formatClock(59.5), '1:00');
      expect(formatClock(0.2), '0:01');
      expect(formatClock(0), '0:00');
      expect(formatClock(1200), '20:00');
    });

    test('invalid time shows zero', () {
      expect(formatClock(-4), '0:00');
      expect(formatClock(double.nan), '0:00');
    });
  });
}
