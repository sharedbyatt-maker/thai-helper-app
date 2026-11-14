plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigning = listOf(
    "BAHTZAY_KEYSTORE_PATH",
    "BAHTZAY_KEYSTORE_PASSWORD",
    "BAHTZAY_KEY_ALIAS",
    "BAHTZAY_KEY_PASSWORD",
).associateWith { providers.environmentVariable(it).orNull }
val hasReleaseSigning = releaseSigning.values.all { !it.isNullOrBlank() }
require(releaseSigning.values.all { it.isNullOrBlank() } || hasReleaseSigning) {
    "Set all four BahtZay Android signing environment variables."
}

android {
    namespace = "io.github.sharedbyattmaker.bahtzay"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Stable identity for ဘတ်ဈေး native previews.
        applicationId = "io.github.sharedbyattmaker.bahtzay"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("bahtzayRelease") {
                storeFile = file(releaseSigning.getValue("BAHTZAY_KEYSTORE_PATH")!!)
                storePassword = releaseSigning.getValue("BAHTZAY_KEYSTORE_PASSWORD")
                keyAlias = releaseSigning.getValue("BAHTZAY_KEY_ALIAS")
                keyPassword = releaseSigning.getValue("BAHTZAY_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("bahtzayRelease")
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

dependencies {
    implementation("com.google.firebase:firebase-messaging:25.0.1")
}
