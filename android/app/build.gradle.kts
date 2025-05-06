plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin must come last
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.studybuddy"
    compileSdk = flutter.compileSdkVersion

    // force all your plugins onto the same NDK:
    ndkVersion = "27.0.12077973"

    compileOptions {
        // ✅ target Java 1.8 so desugaring works reliably
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8

        // ✅ enable core-library desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // jvmTarget should match sourceCompatibility
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.studybuddy"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // only need this—Flutter will auto-include all of your plugin AARs
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}

flutter {
    source = "../.."
}
