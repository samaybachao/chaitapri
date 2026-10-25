# Chai Tapri Tycoon

An offline idle tycoon game for Android (English + Hindi), built with Flutter.
You start with one small chai stall, tap to make chai, hire a helper, unlock new menu items
and slowly grow the stall into a chain. Ads are **optional rewarded videos** only
(Google AdMob + Google consent form). No login, no server, no purchases, no tracking SDK.

* Version: **1.0.0+1** (`pubspec.yaml`)
* Package name (application id): **com.chaitapri.app** (change it before the first upload, see section 8)
* Min Android: flutter default (API 24 / Android 7.0). Target: API 36.

> **Read this first.** The whole game was written without a Flutter compiler (the build machine
> could not run one), so it has been checked with syntax parsers and a custom static checker but
> never compiled. The first thing to do on your PC is the five commands in section 2. If any
> command prints an error, copy it and send it back: it is normally a one-line fix.

---

## 1. One-time PC setup (Windows)

1. Install **Flutter** (stable, 3.47 or newer) and **Android Studio** (it brings the Android SDK and Java).
   Run `flutter doctor` and fix every red item (accept licences with `flutter doctor --android-licenses`).
2. Open a terminal (PowerShell) in this folder (the one that contains `pubspec.yaml`).
3. If `android/local.properties` does not exist, Flutter creates it by itself on the first run.
   The Gradle wrapper files (`gradlew`, `gradle-wrapper.jar`) are also added by Flutter on the first build.

## 2. First run: get packages, analyse, test

```powershell
flutter pub get
dart fix --apply
flutter analyze
flutter test
```

* `dart fix --apply` fixes harmless style hints (for example `prefer_const_constructors`) automatically.
* `flutter analyze` should finish with **No issues found**.
* `flutter test` runs 200+ tests: economy, save/load, offline earnings, daily reward, ads
  configuration, translations, Android project settings and the screens.

Start the game on a phone (USB debugging on) or an emulator:

```powershell
flutter run --dart-define-from-file=env/test.json
```

`env/test.json` forces Google's **test ads**, so you can click them safely. Never click real
ads of your own app: it is invalid traffic and AdMob can ban the account.

Handy while testing: debug builds always show Google test ads. To see the consent form outside Europe,
run a debug build with both `--dart-define=UMP_TEST_DEVICE_ID=<id printed in the log>` and
`--dart-define=UMP_DEBUG_GEOGRAPHY=eea` (or `us`).

## 3. Try a release build on your phone (no Play Store needed)

```powershell
flutter build apk --release --dart-define-from-file=env/test.json
```

The file is `build\app\outputs\flutter-apk\app-release.apk`; copy it to the phone and install it.
Without a signing key (section 4) it is signed with the debug key, which is fine for testing only.

**No Flutter on this PC? Build the APK in the cloud (GitHub Actions).**
1. Push this project to a GitHub repository (the same one you use for the privacy policy page works).
2. Open the repository -> **Actions** -> **Build test APK** -> **Run workflow** (it also runs on every push to `main`).
3. When the run is green (about 5-10 minutes), open it and download **chai-tapri-test-apk** at the bottom, unzip it, and copy `app-release.apk` to the phone.
4. On the phone allow "Install unknown apps" for the app you opened the file with, then install. Google Play Protect may show a harmless "unknown app" notice for a debug-signed test build.

The workflow (`.github/workflows/build-apk.yml`) also runs `flutter analyze` and `flutter test` and shows their output in the run log without stopping the build.

## 4. Signing key (once, keep it forever)

Google Play needs every upload signed with the same *upload key*.

```powershell
# keytool comes with Android Studio; if "keytool" is not found use its full path, e.g.
# "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
keytool -genkey -v -keystore C:\Users\YOU\keys\chai-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then copy `android\key.properties.example` to `android\key.properties` and fill in the passwords
and the path (use forward slashes: `C:/Users/YOU/keys/chai-upload.jks`).

* `key.properties` and `*.jks` are in `.gitignore`. **Never commit or share them.**
* Back up the `.jks` file and both passwords (cloud drive + pen drive). Lost key = painful recovery.
* `flutter build appbundle` refuses to build when `key.properties` is missing, so you can never upload a debug-signed bundle by mistake.
* Keep Play App Signing switched on (default): Google keeps the real app-signing key; yours is only the upload key.

## 5. AdMob setup (real ads)

1. Create an account at <https://admob.google.com> and complete the payment profile (address, PIN verification, bank).
2. **Apps -> Add app -> Android**. Choose "No" for "is the app listed on Google Play" if it is not published yet.
   Copy the **App ID** (`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`).
3. **Ad units -> Add ad unit -> Rewarded.** Create one unit and copy its **Ad unit ID**
   (`ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ`). One unit is enough. You may create separate units for
   better reports and set `ADMOB_REWARDED_BOOST_ID`, `ADMOB_REWARDED_HELPER_ID`, `ADMOB_REWARDED_OFFLINE_ID`,
   `ADMOB_REWARDED_VIP_ID`, `ADMOB_REWARDED_DAILY_ID`; any placement left empty uses `ADMOB_REWARDED_ID`.
4. In AdMob **Privacy & messaging**, set up the **GDPR** message (European regulations) and, if you wish,
   the US-state regulations message. The game shows it through Google's UMP SDK and loads no ad before the
   player has answered where the law requires.
5. Copy `env\prod.example.json` to `env\prod.json` and fill in the values:

```json
{
  "ADS_MODE": "prod",
  "ADMOB_APP_ID": "ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY",
  "ADMOB_REWARDED_ID": "ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ",
  "PRIVACY_POLICY_URL": "https://YOUR-NAME.github.io/chaitapri/privacy-policy.html"
}
```

`env/prod.json` is git-ignored. Check it before every production build:

```powershell
dart run tool/check_env.dart env/prod.json
```

It tells you about sample ids, wrong formats, a different publisher id in app and unit, and so on.

After the app is live on Google Play, link it in AdMob (**Apps -> your app -> App settings -> Link to store**).
If AdMob asks for an `app-ads.txt`, publish it at the root of the developer website you list on the Play listing.
A new account may show few or no ads for a day or two: that is normal.

## 6. Privacy policy page (required by Google Play and AdMob)

`docs/privacy-policy.html` (English + Hindi) is ready. Host it for free with GitHub Pages:

1. Create a public GitHub repository, for example `chaitapri`, and push this project (or only the `docs` folder).
2. **Settings -> Pages -> Build and deployment -> Deploy from a branch -> `main` / `/docs`**.
3. Your page is then `https://YOUR-NAME.github.io/chaitapri/privacy-policy.html`.
4. Put that exact URL in `env/prod.json` (`PRIVACY_POLICY_URL`), in the Play Console (App content -> Privacy policy)
   and in the AdMob app settings.

The default in the code is `https://samaybachao.github.io/chaitapri/privacy-policy.html`. If you use another
name, change it in `env/prod.json`. Developer name and contact e-mail live in `lib/app/constants.dart`
(`kDeveloperName`, `kContactEmail`) and are repeated in `docs/privacy-policy.html`,
`store/privacy-policy.md` and `store/listing-en.md`: search for `samaybachao` and replace everywhere.

## 7. Build the Play Store bundle

1. Section 4 (signing key) and section 5 (`env\prod.json`) are done; `dart run tool/check_env.dart env/prod.json` says OK.
2. Run:

```powershell
flutter build appbundle --release --dart-define-from-file=env/prod.json
```

3. Upload `build\app\outputs\bundle\release\app-release.aab` in the Play Console.

**For the closed test** (see `store/play-console-guide.md`, section 5) build with `env/test.json` instead,
so testers only see Google test ads:

```powershell
flutter build appbundle --release --dart-define-from-file=env/test.json
```

### Every new upload needs a higher version code

Edit these two places and keep the version name equal (a test fails if it differs):

| What | Where | Example |
|---|---|---|
| version name + code | `pubspec.yaml` -> `version:` | `1.0.1+2` |
| shown in Settings | `lib/app/constants.dart` -> `kAppVersion` | `'1.0.1'` |

The number after `+` is the Play **versionCode**: it must grow with every upload, even for test builds.

## 8. Change the package name (before the first upload!)

The application id can never change after the first Play upload. The default `com.chaitapri.app` is a
placeholder. Pick your own (lower case, e.g. `com.yourname.chaitapri`) and run:

```powershell
dart run tool/rename_package.dart com.yourname.chaitapri
flutter clean
flutter pub get
```

The tool updates `lib/app/constants.dart`, `android/app/build.gradle.kts` and moves `MainActivity.kt` to the
matching folder. Then run `flutter test` again (`test/app_meta_test.dart` checks all places agree).

## 9. Publish on Google Play

Everything you need is ready in the `store` folder:

| File | Use |
|---|---|
| `store/play-console-guide.md` | Answers for App content, Data safety, content rating, the 12-tester closed test |
| `store/listing-en.md`, `store/listing-hi.md` | Title, short and full description (English + Hindi) |
| `store/graphics/icon-512.png`, `feature-graphic-1024x500.png` | Store icon and feature graphic |
| `store/screenshots.md` | How to take the screenshots (2 minimum) |
| `store/privacy-policy.md` | Plain-text copy of the privacy policy |

Important Google rules for a **new personal developer account**: you must run a closed test with
**at least 12 testers who stay opted in for 14 days in a row** before you can apply for production access.
Start this early, it is the longest part of the launch.

## 10. Project map

```
lib/
  main.dart                  entry point (portrait lock, error handlers)
  app/                       app widget, start-up (bootstrap), constants, service container
  core/                      PURE DART game rules (no Flutter): config, economy, engine, daily reward, save codec
  services/                  ads (AdMob + consent), save storage, haptics, links, clock, analytics hook
  state/                     GameController (game loop, saving, offline earnings), SettingsController
  l10n/strings.dart          every text, English + Hindi
  ui/                        theme, widgets, stall scene (CustomPainter), panels, dialogs, screens
assets/config/game_config.json   ALL balance numbers (costs, speeds, rewards, timings)
test/                        unit + widget tests
tool/                        check_env.dart, rename_package.dart, simulate_economy.py, make_icons.py
env/                         build settings (test.json, prod.example.json)
store/ docs/                 Play Store texts, graphics, privacy policy page
android/                     Android project (signing, AdMob app id, manifest, icons)
```

### Tuning the game balance

All numbers are in `assets/config/game_config.json`. Before changing them see what happens to the pace:

```powershell
python tool/simulate_economy.py
```

It prints the first hour of play and the days an engaged/casual player needs to finish all upgrades.
`flutter test` (`test/simulation_test.dart`) checks the same targets, so a bad edit fails the tests.

### Icons and store graphics

`python tool/make_icons.py` (needs `pip install pillow`) redraws the launcher icons, start-up logo and
the Play Store graphics. Edit the colours/shape in that file and run it again.

### Translations

Add or change texts only in `lib/l10n/strings.dart` (both `en` and `hi`). `test/l10n_test.dart` fails if a key is
missing in one language, a placeholder differs, or a text is not used.

## 11. Troubleshooting

| Problem | Fix |
|---|---|
| `flutter analyze` prints "info" lines | Run `dart fix --apply`, then analyse again. |
| Gradle / AGP error right after `flutter build` | Update Flutter (`flutter upgrade`) and run `flutter clean`. If it persists see "Android project fallback" below. |
| `android/key.properties not found` | Section 4. Needed only for `appbundle`. |
| Build says the AdMob app id is invalid / app crashes at start with an AdMob message | `ADMOB_APP_ID` must contain the `~`; run `dart run tool/check_env.dart env/prod.json`. |
| No ads show | New AdMob units need up to a day; check internet; check the consent answer (Settings -> Ad privacy choices). The game stays playable without ads. |
| Ads do not show on the emulator | Use an emulator image with Google Play services, or a real phone. |
| `The Gradle wrapper was not found` | Run `flutter build apk` once; Flutter creates it. |
| App stops right after start on a phone | Run the **Emulator smoke test** workflow (Actions tab). It installs the release APK on an Android emulator, plays a short session and publishes screenshots + logcat on the Releases page (`emulator-...`). A past crash (WorkManager/Room removed by R8) is fixed by `android/app/proguard-rules.pro`; keep that file. |

### Android project fallback

The Android folder follows the Flutter 3.47 template (AGP 9.1, Gradle 9.3, Kotlin 2.4). If a future Flutter
version asks for a different Android setup, create a fresh template and re-apply the changes of this project:

1. `flutter create --platforms=android --org com.yourname --project-name chai_tapri tmp_android` in a spare folder.
2. Copy its `android` folder over this one, then re-apply from the old files: the `signing`, `dart-defines`
   and `admobAppId` parts of `android/app/build.gradle.kts`; `targetSdk = 36`;
   `AndroidManifest.xml` (permissions, AdMob meta-data with `${admobAppId}`, portrait orientation);
   `res/` (icons, launch background, backup rules).

## 12. Ideas for version 1.1

* Second stall "Railway Station" (the menu already shows a coming-soon card) to extend the story to 30+ days.
* Sound effects and a music on/off switch.
* Daily reminder notifications, Firebase analytics/crash reports (then update the Data safety form and privacy policy!).
* Cloud backup of the save, more languages.
