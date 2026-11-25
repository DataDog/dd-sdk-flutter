import io.gitlab.arturbosch.detekt.extensions.DetektExtension
import org.jlleitschuh.gradle.ktlint.KtlintExtension

plugins {
    id("org.jlleitschuh.gradle.ktlint") version "14.2.0" apply false
    id("io.gitlab.arturbosch.detekt") version "1.23.8" apply false
}

val repositoryRoot = rootDir.resolve("../../..")
val localPlugins = mapOf(
    "datadog_flutter_plugin_android" to
        "packages/datadog_flutter_plugin/datadog_flutter_plugin/example/android/detekt.yml",
    "datadog_session_replay" to "packages/datadog_session_replay/example/android/detekt.yml",
    "datadog_webview_tracking" to "packages/datadog_webview_tracking/example/android/detekt.yml",
    "datadog_inappwebview_tracking" to "packages/datadog_inappwebview_tracking/example/android/detekt.yml",
)

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

layout.buildDirectory.set(file("../build"))

subprojects {
    layout.buildDirectory.set(rootProject.layout.buildDirectory.dir(name))

    localPlugins[name]?.let { detektConfig ->
        pluginManager.apply("org.jlleitschuh.gradle.ktlint")
        extensions.configure<KtlintExtension> {
            android.set(true)
            filter {
                exclude("**/build/**")
            }
        }

        pluginManager.apply("io.gitlab.arturbosch.detekt")
        extensions.configure<DetektExtension> {
            config.setFrom(repositoryRoot.resolve(detektConfig))
        }
    }
}

subprojects {
    evaluationDependsOn(":app")
}

tasks.register("nativeTest") {
    group = "verification"
    description = "Runs debug JVM unit tests for the local Android plugins."
    dependsOn(localPlugins.keys.map { ":$it:testDebugUnitTest" })
}

tasks.register("nativeLint") {
    group = "verification"
    description = "Runs Android Lint for the local Android plugins."
    dependsOn(localPlugins.keys.map { ":$it:lintDebug" })
}

tasks.register("nativeCheck") {
    group = "verification"
    description = "Runs native unit tests, Android Lint, ktlint, and detekt."
    dependsOn("nativeTest", "nativeLint")
    dependsOn(localPlugins.keys.flatMap { listOf(":$it:ktlintCheck", ":$it:detekt") })
}

tasks.register<Delete>("clean") {
    group = "build"
    description = "Deletes build outputs for the Android workspace."
    delete(rootProject.layout.buildDirectory)
}
