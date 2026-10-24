import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Release signing. android/key.properties is created by you (see README.md,
// section "Signing key") and is git-ignored. NEVER commit it or the .jks file.
// ---------------------------------------------------------------------------
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

// ---------------------------------------------------------------------------
// Values passed with --dart-define / --dart-define-from-file=env/<file>.json.
// Flutter hands them to Gradle as Base64("KEY=value") entries separated by ",".
// This lets ONE env file drive both Dart (ad unit IDs) and the manifest
// (AdMob application ID).
// ---------------------------------------------------------------------------
val dartDefines = mutableMapOf<String, String>()
if (project.hasProperty("dart-defines")) {
    project.property("dart-defines").toString().split(",").forEach { entry ->
        if (entry.isNotBlank()) {
            try {
                val decoded = String(Base64.getDecoder().decode(entry), Charsets.UTF_8)
                val separator = decoded.indexOf("=")
                if (separator > 0) {
                    dartDefines[decoded.substring(0, separator)] = decoded.substring(separator + 1)
                }
            } catch (e: IllegalArgumentException) {
                // Not one of ours (not valid Base64): ignore.
            }
        }
    }
}

// Google's public SAMPLE AdMob application ID: safe for development and for
// closed-test builds. Production builds must pass ADMOB_APP_ID (env/prod.json).
val sampleAdMobAppId = "ca-app-pub-3940256099942544~3347511713"
val adMobAppId: String = dartDefines["ADMOB_APP_ID"]?.takeIf { it.isNotBlank() } ?: sampleAdMobAppId

android {
    namespace = "com.chaitapri.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.chaitapri.app"
        minSdk = flutter.minSdkVersion
        // Google Play: new apps and updates must target API 36 from 31 Aug 2026.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = adMobAppId
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Without key.properties, `flutter run --release` still works (debug key).
            // A Play upload (bundleRelease) refuses to build, see the check below.
            signingConfig =
                if (keystorePropertiesFile.exists()) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Never produce an upload bundle signed with the debug key by accident.
gradle.taskGraph.whenReady {
    if (hasTask(":app:bundleRelease") && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "android/key.properties not found. Create your upload keystore first " +
                "(README.md, section 'Signing key') before building the release bundle."
        )
    }
}
