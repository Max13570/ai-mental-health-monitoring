plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") version "1.9.22" // Changed from 2.0.20 to 1.9.22
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.mentalhealthmonitoringapp"
    compileSdk = 34 // Changed from 33 to 34 to match Flutter's recommendation

    defaultConfig {
        applicationId = "com.example.mentalhealthmonitoringapp"
        minSdk = 21 // Changed from 23 to 21 (Flutter's default minimum)
        targetSdk = 34 // Changed from 33 to 34
        versionCode = 1
        versionName = "1.0.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        coreLibraryDesugaringEnabled = true // Add this for Java 8+ features
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            // Add these signing configs if you're building for release
            // signingConfig signingConfigs.debug
            isMinifyEnabled = false
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }

    // Add this block for Flutter projects
    buildFeatures {
        buildConfig = true
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4") // Add this line
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.22") // Add this line
}