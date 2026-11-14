pluginManagement {
    val localPropertiesFile = settings.rootDir.resolve("local.properties")
    if (!localPropertiesFile.exists()) {
        throw GradleException("local.properties file not found at ${localPropertiesFile.absolutePath}")
    }

    val props = java.util.Properties().apply {
        localPropertiesFile.inputStream().use { load(it) }
    }

    val flutterSdkPath = props.getProperty("flutter.sdk")
        ?: throw GradleException("flutter.sdk not set in local.properties")

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "mentalhealthmonitoringapp"
include(":app")