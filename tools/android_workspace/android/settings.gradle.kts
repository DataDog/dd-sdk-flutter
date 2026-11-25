pluginManagement {
    val properties = java.util.Properties()
    val localProperties = file("local.properties")
    require(localProperties.exists()) {
        "Run melos setup:android to configure the Flutter SDK."
    }
    localProperties.inputStream().use { properties.load(it) }
    val flutterSdkPath = requireNotNull(properties.getProperty("flutter.sdk")) {
        "Run melos setup:android to configure the Flutter SDK."
    }
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.5.3" apply false
    id("org.jetbrains.kotlin.android") version "2.4.21" apply false
}

rootProject.name = "datadog_android_workspace"
include(":app")
