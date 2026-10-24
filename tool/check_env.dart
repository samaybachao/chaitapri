// Checks an env file before a production build.
//
//   dart run tool/check_env.dart env/prod.json
//
// Exit code 0 = ready, 1 = something must be fixed. Nothing is changed or sent anywhere.
import 'dart:convert';
import 'dart:io';

const String sampleAppId = 'ca-app-pub-3940256099942544~3347511713';
final RegExp appIdPattern = RegExp(r'^ca-app-pub-(\d{16})~\d{10}$');
final RegExp unitIdPattern = RegExp(r'^ca-app-pub-(\d{16})/\d{10}$');
const List<String> placementKeys = <String>[
  'ADMOB_REWARDED_BOOST_ID',
  'ADMOB_REWARDED_HELPER_ID',
  'ADMOB_REWARDED_OFFLINE_ID',
  'ADMOB_REWARDED_VIP_ID',
  'ADMOB_REWARDED_DAILY_ID',
];

void main(List<String> args) {
  final String path = args.isEmpty ? 'env/prod.json' : args.first;
  final File file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Not found: $path');
    stderr.writeln('Copy env/prod.example.json to env/prod.json and fill in your values.');
    exit(1);
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    stderr.writeln('$path is not valid JSON: ${error.message}');
    exit(1);
  }
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('$path must contain a JSON object like {"ADS_MODE": "prod", ...}');
    exit(1);
  }

  final Map<String, dynamic> env = decoded;
  final List<String> problems = <String>[];
  final List<String> warnings = <String>[];
  String value(String key) => (env[key] ?? '').toString().trim();

  if (value('ADS_MODE').toLowerCase() != 'prod') {
    problems.add('ADS_MODE must be "prod" for a Play Store build (it is "${value('ADS_MODE')}"). '
        'With "test" the game shows Google test ads only.');
  }

  final RegExpMatch? app = appIdPattern.firstMatch(value('ADMOB_APP_ID'));
  String? publisher;
  if (value('ADMOB_APP_ID') == sampleAppId) {
    problems.add('ADMOB_APP_ID is Google\'s sample id. Use your own app id from the AdMob console.');
  } else if (app == null) {
    problems.add('ADMOB_APP_ID must look like ca-app-pub-1234567890123456~1234567890 (with "~").');
  } else {
    publisher = app.group(1);
  }

  final List<String> unitKeys = <String>['ADMOB_REWARDED_ID', ...placementKeys];
  int validUnits = 0;
  for (final String key in unitKeys) {
    final String text = value(key);
    if (text.isEmpty) {
      continue;
    }
    final RegExpMatch? match = unitIdPattern.firstMatch(text);
    if (match == null) {
      problems.add('$key must look like ca-app-pub-1234567890123456/1234567890 (with "/").');
      continue;
    }
    validUnits += 1;
    if (publisher != null && match.group(1) != publisher) {
      problems.add('$key belongs to a different AdMob account than ADMOB_APP_ID.');
    }
  }
  if (validUnits == 0) {
    problems.add('No rewarded ad unit id. Set ADMOB_REWARDED_ID (one unit for all ads) '
        'or the five ADMOB_REWARDED_*_ID values.');
  } else if (value('ADMOB_REWARDED_ID').isEmpty) {
    final List<String> missing = placementKeys.where((String k) => value(k).isEmpty).toList();
    if (missing.isNotEmpty) {
      warnings.add('No ADMOB_REWARDED_ID and no value for ${missing.join(', ')}: '
          'those ad buttons will show no ad.');
    }
  }

  final String policy = value('PRIVACY_POLICY_URL');
  if (policy.isEmpty) {
    warnings.add('PRIVACY_POLICY_URL is not set: the game uses the default from '
        'lib/app/constants.dart. Make sure that page exists and is the same URL as in Play Console.');
  } else if (!policy.startsWith('https://') || policy.contains('YOUR-NAME')) {
    problems.add('PRIVACY_POLICY_URL must be your real https:// page.');
  }

  if (!File('android/key.properties').existsSync()) {
    problems.add('android/key.properties is missing: create your upload key first '
        '(README.md, "Signing key").');
  }

  for (final String warning in warnings) {
    stdout.writeln('WARNING: $warning');
  }
  if (problems.isEmpty) {
    stdout.writeln('OK: $path looks ready for a production build.');
    exit(0);
  }
  for (final String problem in problems) {
    stdout.writeln('PROBLEM: $problem');
  }
  exit(1);
}
