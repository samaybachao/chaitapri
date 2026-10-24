/// Number and time formatting for the UI. Pure functions, covered by tests.
library;

const List<String> _suffixes = <String>[
  '',
  'K',
  'M',
  'B',
  'T',
  'Qa',
  'Qi',
  'Sx',
  'Sp',
  'Oc',
  'No',
  'Dc',
];

/// Coin amounts: `0`, `999`, `1.23K`, `12.3K`, `123K`, `1.5M`, ...
String formatNumber(double value) {
  if (value.isNaN || value.isInfinite || value < 1) {
    return '0';
  }
  if (value < 1000) {
    return value.floor().toString();
  }
  double scaled = value;
  int tier = 0;
  while (scaled >= 1000 && tier < _suffixes.length - 1) {
    scaled = scaled / 1000;
    tier++;
  }
  String text = _significant(scaled);
  // 999.96K is printed as "1000K": move it up to "1M" instead.
  final double rounded = double.parse(text);
  if (rounded >= 1000 && tier < _suffixes.length - 1) {
    scaled = rounded / 1000;
    tier++;
    text = _significant(scaled);
  }
  return '$text${_suffixes[tier]}';
}

/// Income per second: `0.6`, `3.2`, `45.2`, `460`, `1.2K`, ...
String formatRate(double value) {
  if (value.isNaN || value.isInfinite || value <= 0) {
    return '0';
  }
  if (value < 1) {
    return _trimZeros(value.toStringAsFixed(2));
  }
  if (value < 100) {
    return _trimZeros(value.toStringAsFixed(1));
  }
  return formatNumber(value);
}

/// Multipliers and percentages with up to two decimals: `1.2`, `12`, `0.985`.
String formatFactor(double value) {
  if (value.isNaN || value.isInfinite) {
    return '0';
  }
  if (value >= 100) {
    return value.round().toString();
  }
  if (value >= 10) {
    return _trimZeros(value.toStringAsFixed(1));
  }
  return _trimZeros(value.toStringAsFixed(2));
}

/// Whole percent: 0.295 -> `30` (call with the fraction).
String formatPercent(double fraction) {
  if (fraction.isNaN || fraction.isInfinite || fraction <= 0) {
    return '0';
  }
  return (fraction * 100).round().toString();
}

/// `2h 15m`, `5m 30s`, `45s`. The unit texts can be translated.
String formatDuration(
  double seconds, {
  String hourUnit = 'h',
  String minuteUnit = 'm',
  String secondUnit = 's',
}) {
  final int total = (seconds.isFinite && seconds > 0) ? seconds.floor() : 0;
  final int hours = total ~/ 3600;
  final int minutes = (total % 3600) ~/ 60;
  final int secs = total % 60;
  if (hours > 0) {
    return minutes > 0 ? '$hours$hourUnit $minutes$minuteUnit' : '$hours$hourUnit';
  }
  if (minutes > 0) {
    return secs > 0 ? '$minutes$minuteUnit $secs$secondUnit' : '$minutes$minuteUnit';
  }
  return '$secs$secondUnit';
}

/// Countdown clock `m:ss` (for example the boost timer): 272 -> `4:32`.
String formatClock(double seconds) {
  final int total = (seconds.isFinite && seconds > 0) ? seconds.ceil() : 0;
  final int minutes = total ~/ 60;
  final int secs = total % 60;
  return '$minutes:${secs.toString().padLeft(2, '0')}';
}

String _significant(double value) {
  if (value < 10) {
    return _trimZeros(value.toStringAsFixed(2));
  }
  if (value < 100) {
    return _trimZeros(value.toStringAsFixed(1));
  }
  return value.toStringAsFixed(0);
}

String _trimZeros(String text) {
  if (!text.contains('.')) {
    return text;
  }
  String result = text;
  while (result.endsWith('0')) {
    result = result.substring(0, result.length - 1);
  }
  if (result.endsWith('.')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}
