allprojects {
    repositories {
        google()
        mavenCentral()
        // Add JitPack repository for video conferencing dependencies
        maven { url = uri("https://jitpack.io") }
        // Add repository for React Native libraries (required by jitsi_meet)
        maven { url = uri("https://www.jitpack.io") }
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

    // Configure all subprojects for video conferencing compatibility
    afterEvaluate {
        if (hasProperty("android")) {
            extensions.configure<com.android.build.gradle.BaseExtension> {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_11
                    targetCompatibility = JavaVersion.VERSION_11
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Configure all projects to use the same versions
ext {
    set("compileSdkVersion", 34)
    set("targetSdkVersion", 34)
    set("minSdkVersion", 21) // Required for video conferencing
}