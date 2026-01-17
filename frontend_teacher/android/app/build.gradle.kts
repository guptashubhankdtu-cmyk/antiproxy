import java.util.Properties
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // id("com.google.gms.google-services") // Commented out - not using Firebase
}

android {
    // Add this code

    namespace = "com.dtuaims.antiproxy.teacher"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
   
    defaultConfig {
        // Unique Application ID for teacher app
        applicationId = "com.dtuaims.antiproxy.teacher"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdkVersion(flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode()
        versionName = flutter.versionName()
    }
    // Replace your existing signingConfigs block with this one
    signingConfigs {
        getByName("debug") {
            val keyPropertiesFile = rootProject.file("key.properties")
            if (keyPropertiesFile.exists()) {
                val keyProperties = Properties()
                keyProperties.load(keyPropertiesFile.inputStream())
                storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
        create("release") {
            val keyPropertiesFile = rootProject.file("key.properties")
            if (keyPropertiesFile.exists()) {
                val keyProperties = Properties()
                keyProperties.load(keyPropertiesFile.inputStream())
                storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
            // If key.properties doesn't exist, release config will be empty
            // and we'll fall back to debug signing in buildTypes
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            // Use release signing if configured, otherwise fall back to debug
            val keyPropertiesFile = rootProject.file("key.properties")
            if (keyPropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Fall back to debug signing for release builds if no key.properties
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
