import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Release signing. Create android/key.properties (gitignored) from
// key.properties.example pointing at your upload keystore — see docs/RELEASE.md.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.vabs.communiq"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.vabs.communiq"
        // 23, not Flutter's default 21: the `record` plugin's Android
        // implementation (record_android) requires API 23+ for audio capture,
        // which the practice-session mic flow depends on.
        // record_android (microphone capture) declares minSdk 23, so the
        // Flutter default of 21 fails the manifest merge and nothing builds.
        // The merge reverted this; it was pinned deliberately.
        minSdk = 23
        // Pinned rather than following the Flutter default so a Flutter
        // upgrade can't silently drop below Google Play's target-API floor.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Without key.properties the release build falls back to the debug
            // key so `flutter run --release` still works locally. Play Console
            // rejects debug-signed bundles, so a store build needs the keystore.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("android/key.properties not found — release build is signed with the DEBUG key and cannot be uploaded to Play.")
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
