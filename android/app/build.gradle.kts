import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("../local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

android {
    namespace = "dev.vz.ljod"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlin {
        jvmToolchain(21)
    }

    defaultConfig {
        applicationId = "dev.vz.ljod"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keystorePathProp = localProperties.getProperty("ANDROID_KEYSTORE_PATH") ?: "app/keystore/ljod.p12"
            storeFile = rootProject.file(keystorePathProp)
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD") 
                ?: localProperties.getProperty("ANDROID_KEYSTORE_PASSWORD")
                ?: ""
            keyAlias = System.getenv("ANDROID_KEY_ALIAS") 
                ?: localProperties.getProperty("ANDROID_KEY_ALIAS")
                ?: "ljod"
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD") 
                ?: localProperties.getProperty("ANDROID_KEY_PASSWORD")
                ?: ""
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
