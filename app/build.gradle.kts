plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
    alias(libs.plugins.detekt)
    alias(libs.plugins.ktlint)
}

detekt {
    config.setFrom(file("$rootDir/gradle/config/detekt.yml"))
    buildUponDefaultConfig = true
    allRules = false
    toolVersion = "1.23.8"
}

android {
    namespace = "dev.vz.ljod"
    compileSdk = 37

    defaultConfig {
        applicationId = "dev.vz.ljod"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        create("release") {
            storeFile =
                file(
                    (findProperty("ANDROID_KEYSTORE_PATH") as String?)
                        ?: System.getenv("ANDROID_KEYSTORE_PATH")
                        ?: "keystore/ljod.p12",
                )
            storePassword =
                (findProperty("ANDROID_KEYSTORE_PASSWORD") as String?)
                    ?: System.getenv("ANDROID_KEYSTORE_PASSWORD")
                    ?: System.getProperty("ANDROID_KEYSTORE_PASSWORD")
                    ?: ""
            keyAlias = (findProperty("ANDROID_KEY_ALIAS") as String?) ?: System.getenv("ANDROID_KEY_ALIAS") ?: "ljod"
            keyPassword =
                (findProperty("ANDROID_KEY_PASSWORD") as String?)
                    ?: System.getenv("ANDROID_KEY_PASSWORD")
                    ?: System.getProperty("ANDROID_KEY_PASSWORD")
                    ?: ""
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    kotlin {
        jvmToolchain(21)
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    lint {
        abortOnError = true
        warningsAsErrors = true
    }
}

dependencies {
    // Compose (BOM)
    val composeBom = platform(libs.compose.bom)
    implementation(composeBom)
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons)
    implementation(libs.compose.animation)
    implementation(libs.compose.foundation)
    debugImplementation(libs.compose.ui.tooling)

    // Core
    implementation(libs.core.ktx)
    implementation(libs.activity.compose)
    implementation(libs.lifecycle.runtime)
    implementation(libs.lifecycle.viewmodel)

    // Media3
    implementation(libs.media3.exoplayer)
    implementation(libs.media3.session)
    implementation(libs.media3.common)

    // DI
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation)
    implementation(libs.hilt.work)
    ksp(libs.hilt.work.compiler)

    // Persistence
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)
    implementation(libs.datastore.preferences)

    // Logging
    implementation(libs.timber)

    // Serialization + Coroutines
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines)

    // Image loading
    implementation(libs.coil.compose)
    implementation(libs.coil.network.okhttp)

    // Network
    implementation(libs.okhttp)
    implementation(libs.retrofit)
    implementation(libs.retrofit.kotlinx)
    implementation(libs.okhttp.logging)
    implementation(libs.biometric)
    implementation(libs.security.crypto)
    implementation(libs.workmanager)
    implementation(libs.fragment.compose)
    implementation(libs.datastore.preferences)
    implementation(libs.datastore)
    implementation(libs.glance)
    implementation(libs.glance.material3)
    coreLibraryDesugaring(libs.desugar)
}
