/// App-wide constants. Review the values marked CONFIGURE before you release.
library;

/// Name shown inside the game (the launcher name lives in android/.../strings.xml).
const String kAppName = 'Chai Tapri Tycoon';

/// Must match `applicationId` in android/app/build.gradle.kts.
/// `dart run tool/rename_package.dart <new.id>` updates both places.
const String kApplicationId = 'com.chaitapri.app';

/// Must match `version:` in pubspec.yaml (test/app_meta_test.dart checks it).
const String kAppVersion = '1.0.0';

/// CONFIGURE: developer / publisher name shown in Settings > Credits.
const String kDeveloperName = 'samaybachao';

/// CONFIGURE: support e-mail (also used in the privacy policy and store listing).
const String kContactEmail = 'samaybachao.official@gmail.com';

/// CONFIGURE: public URL of the privacy policy page (Play Console needs the same URL).
/// Override at build time with `"PRIVACY_POLICY_URL": "..."` in env/*.json.
const String kPrivacyPolicyUrl = String.fromEnvironment(
  'PRIVACY_POLICY_URL',
  defaultValue: 'https://samaybachao.github.io/chaitapri/privacy-policy.html',
);

/// Play Store web page of the app, used as the "Rate us" fallback.
String get kPlayStoreWebUrl =>
    'https://play.google.com/store/apps/details?id=$kApplicationId';

/// Play Store deep link of the app ("Rate us").
String get kPlayStoreMarketUrl => 'market://details?id=$kApplicationId';

/// How often the game logic advances (seconds). The UI never needs more than this.
const double kTickSeconds = 0.1;

/// A single game-loop step never advances more than this (seconds). Longer gaps
/// (the app was frozen by the OS) are handled by the offline-earning logic instead.
const double kMaxTickSeconds = 1.0;

/// How often the game is written to disk while playing (seconds).
const double kAutosaveSeconds = 10.0;
