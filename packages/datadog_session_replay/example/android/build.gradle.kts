buildscript {
    repositories {
        google()
        mavenCentral()
        maven("https://plugins.gradle.org/m2/")
    }

    dependencies {
        classpath("org.jlleitschuh.gradle:ktlint-gradle:14.2.0")
        classpath("io.gitlab.arturbosch.detekt:detekt-gradle-plugin:1.19.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    if (project.projectDir.canonicalPath.startsWith(rootProject.projectDir.canonicalPath)) {
        apply(from = "${project.rootDir}/buildscripts/ktlint.gradle")
        apply(from = "${project.rootDir}/buildscripts/detekt.gradle")
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

// We need to ignore tests in included projects because `flutter_test_goldens` pulls in
// `flutter_android_lifecycle` which has a dependency on a version of mockito that requires
// Java 24.
subprojects {
    if (!project.projectDir.canonicalPath.startsWith(rootProject.projectDir.canonicalPath)) {
        afterEvaluate {
            tasks.matching { task -> task.name.contains("test", ignoreCase = true) }.configureEach {
                setEnabled(false)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
