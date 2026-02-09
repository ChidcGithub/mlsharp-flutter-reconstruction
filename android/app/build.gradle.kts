plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mlsharp.flutter.mlsharp_flutter"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
        freeCompilerArgs += listOf("-Xskip-prerelease-check", "-Xallow-jvm-ir-dependencies")
    }

    defaultConfig {
        applicationId = "com.mlsharp.flutter.mlsharp_flutter"
        minSdk = 24 // 显式设置 minSdk 以确保兼容性
        targetSdk = 36 // 强制 targetSdk 也为 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        externalNativeBuild {
            cmake {
                // 显式指定 CMake 路径，解决 CI 环境中找不到 CMake 的问题
                path = file("/usr/bin/cmake")
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
