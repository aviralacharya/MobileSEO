import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("../key/key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.isFile) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val includeNativeDebugSymbols =
    providers.gradleProperty("includeNativeDebugSymbols").orNull == "true"

val validateReleaseSigningCredentials by tasks.registering {
    doLast {
        check(keystorePropertiesFile.isFile) {
            "Release signing requires key/key.properties in the project root."
        }
        for (property in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
            check(!keystoreProperties.getProperty(property).isNullOrBlank()) {
                "Release signing requires $property in key/key.properties."
            }
        }
    }
}

android {
    namespace = "abiral.mobile.seo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "abiral.mobile.seo"
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
        create("release") {
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeType = "JKS"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Generate native crash symbols with a separate diagnostic build.
            ndk.debugSymbolLevel = if (includeNativeDebugSymbols) "SYMBOL_TABLE" else "NONE"
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

tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(validateReleaseSigningCredentials)
}
