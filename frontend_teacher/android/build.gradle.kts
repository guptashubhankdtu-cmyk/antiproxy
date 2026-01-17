buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.4.1")
        // classpath("com.google.gms:google-services:4.4.1") // Commented out - not using Firebase
    }
}

// Provide flutter config for plugins expecting Groovy ext.flutter.*
extra["flutter"] = mapOf(
    "compileSdkVersion" to 34,
    "minSdkVersion" to 21,
    "targetSdkVersion" to 34
)

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
