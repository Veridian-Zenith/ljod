import java.io.File
import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

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

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    defaultConfig {
        applicationId = "dev.vz.ljod"
        minSdk = 35
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            /**
             * Signing material never lives in this repository, so the build
             * accepts it as content first and as a path second:
             *
             *  1. `ANDROID_KEYSTORE_BASE64` — the keystore itself, base64
             *     encoded. This is what CI passes from repository secrets.
             *  2. `ANDROID_KEYSTORE_PATH` — a path to a keystore outside the
             *     repository, for local release builds.
             *
             * The base64 form is decoded into the disposable Gradle build
             * directory, never into tracked source.
             */
            fun decodeInlineKeystore(encoded: String): File? = runCatching {
                val cleaned = encoded.filterNot { it.isWhitespace() }
                require(cleaned.isNotEmpty()) { "empty keystore secret" }
                // Outside build/: `clean` must not be able to delete the key
                // between configuration and signing. Ignored by git.
                val output = File(
                    rootProject.projectDir,
                    ".gradle-signing/ljod-upload.p12",
                )
                output.parentFile?.mkdirs()
                output.writeBytes(Base64.getDecoder().decode(cleaned))
                output.setReadable(false, false)
                output.setReadable(true, true)
                output.setWritable(true, true)
                output
            }.getOrNull()

            fun resolveKeystore(path: String): File? {
                val direct = File(path)
                // A relative path may be written from the android/ directory or
                // from the repository root; accept either, and require a file
                // (never a directory) so a stale path fails loudly.
                val candidates = if (direct.isAbsolute) {
                    listOf(direct)
                } else {
                    listOf(rootProject.file(path), rootProject.file("../$path"))
                }
                return candidates.firstOrNull { it.isFile }
            }

            val inlineKeystore = System.getenv("ANDROID_KEYSTORE_BASE64")
                ?.takeIf { it.isNotBlank() }
                ?.let { decodeInlineKeystore(it) }
            val configuredPath = System.getenv("ANDROID_KEYSTORE_PATH")
                ?: localProperties.getProperty("ANDROID_KEYSTORE_PATH")

            storeFile = inlineKeystore
                ?: configuredPath
                    ?.takeIf { it.isNotBlank() }
                    ?.let { resolveKeystore(it) }
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                ?: localProperties.getProperty("ANDROID_KEYSTORE_PASSWORD")
                ?: ""
            keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                ?: localProperties.getProperty("ANDROID_KEY_ALIAS")
                ?: "ljod"
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
                ?: localProperties.getProperty("ANDROID_KEY_PASSWORD")
                ?: ""

            if (storeFile == null) {
                val reason = configuredPath?.takeIf { it.isNotBlank() }?.let {
                    "ANDROID_KEYSTORE_PATH='$it' does not point at an existing file."
                } ?: "Neither ANDROID_KEYSTORE_BASE64 nor ANDROID_KEYSTORE_PATH is set."
                logger.lifecycle(
                    "Ljod: no signing key. $reason Release builds will fail until " +
                        "one is provided as ANDROID_KEYSTORE_BASE64 (content) or " +
                        "ANDROID_KEYSTORE_PATH (absolute, outside the repository)."
                )
            } else {
                logger.lifecycle(
                    "Ljod: release signing key ${storeFile!!.absolutePath} " +
                        "(alias '${keyAlias ?: "ljod"}')."
                )
            }
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

    lint {
        checkReleaseBuilds = true
        abortOnError = false
        disable.addAll(listOf("MissingPermission", "InvalidPackage"))
    }
}

kotlin {
    compilerOptions {
        // Target 17 bytecode without requiring a JDK 17 toolchain to be
        // installed; the Gradle JDK (21 in CI) compiles it fine.
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
    }
}

flutter {
    source = "../.."
}
