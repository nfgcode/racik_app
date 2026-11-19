import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kunci unggah (upload key) untuk Play Store dibaca dari android/key.properties.
// File itu dan file .jks-nya TIDAK boleh masuk git. Buat lewat:
//   powershell -ExecutionPolicy Bypass -File tool\buat_upload_key.ps1
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    // Package name di Play Store. TIDAK bisa diganti setelah upload pertama.
    namespace = "com.nfgcode.racik"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.nfgcode.racik"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion // Play Store mewajibkan API terbaru (36)
        versionCode = flutter.versionCode // dari pubspec.yaml: version: x.y.z+versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("upload") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Tanpa key.properties, rilis ditandatangani kunci debug supaya
            // `flutter run --release` tetap jalan. File seperti itu DITOLAK Play Store.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("upload")
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
