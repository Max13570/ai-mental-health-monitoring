plugins {
    id "com.android.application"
    id "org.jetbrains.kotlin.android" version "1.9.22"
    id "dev.flutter.flutter-gradle-plugin"
}

android {
    namespace "com.example.mentalhealthmonitoringapp"
    compileSdk 34

    defaultConfig {
        applicationId "com.example.mentalhealthmonitoringapp"
        minSdk 21
        targetSdk 34
        versionCode 1
        versionName "1.0.0"
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
                targetCompatibility JavaVersion.VERSION_17
                coreLibraryDesugaringEnabled true
    }

    kotlinOptions {
        jvmTarget "17"
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug
                    minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
        debug {
            signingConfig signingConfigs.debug
        }
    }

    buildFeatures {
        buildConfig true
    }
}

flutter {
    source "../.."
}

dependencies {
    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.0.4"
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.22"
    implementation "androidx.core:core-ktx:1.12.0"
}