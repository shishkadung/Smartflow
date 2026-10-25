import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Debug builds do not need this file. Release builds require their own key.
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { stream -> keystoreProperties.load(stream) }
}

android {
    namespace = "com.urbiztondo.smartflow"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.urbiztondo.smartflow"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties.getProperty("STORE_FILE") ?: "smartflow-release.jks")
                storePassword = keystoreProperties.getProperty("STORE_PASSWORD") ?: ""
                keyAlias = keystoreProperties.getProperty("KEY_ALIAS") ?: "smartflow"
                keyPassword = keystoreProperties.getProperty("KEY_PASSWORD") ?: ""
            }
        }
    }

    buildTypes {
        release {
            // Missing release credentials must fail signing, never use the debug key.
            signingConfig = signingConfigs.getByName("release")
            // Minify and shrink code for release builds
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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

// AGP can otherwise emit an unsigned release when the signing config is incomplete.
val checkReleaseSigning by tasks.registering {
    group = "verification"
    description = "Require the protected release key before producing release artifacts."
    doLast {
        check(keystorePropertiesFile.isFile) {
            "Release signing requires android/keystore.properties. Debug signing is not allowed for a release."
        }
        for (field in listOf("STORE_FILE", "STORE_PASSWORD", "KEY_ALIAS", "KEY_PASSWORD")) {
            check(!keystoreProperties.getProperty(field).isNullOrBlank()) {
                "Release signing configuration is missing $field."
            }
        }
        check(file(keystoreProperties.getProperty("STORE_FILE")).isFile) {
            "The configured release keystore file does not exist."
        }
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(checkReleaseSigning)
}
