import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "tech.mbkm.energrow"
    compileSdk = 36

    // No ndkVersion on purpose, but note it does NOT prevent the download.
    //
    // Nothing in this app compiles native code, so pinning 30.0.16248370 here
    // only made AGP fetch an NDK that nothing uses. Removing the line does not
    // stop the fetch either: AGP still installs Flutter's default NDK
    // (28.2.13676358) during configuration. Verified on a clean build with no
    // ndk/ and no cmake/ in the SDK: both get installed, and the build then
    // produces zero .o files, no build.ninja, and no libdartjni.so.
    //
    // The line stays out so that if a future dependency really needs the NDK, it
    // resolves to the same version plugins ask for (flutter.ndkVersion) instead
    // of a second, divergent copy. The download itself is AGP behaviour and is
    // not avoidable from this file; see AGENTS.md.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    defaultConfig {
        applicationId = "tech.mbkm.energrow"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // NotificationCompat, for the native alarm module to post an alarm without
    // starting a Flutter engine. Already on the classpath transitively through
    // the Flutter embedding and flutter_local_notifications, but declared so the
    // background alarm feature does not silently depend on a transitive edge.
    implementation("androidx.core:core-ktx:1.13.1")

    // Runs the parity tests that pin AlarmEvaluator and AlarmMessageFormat to
    // the same behaviour as their Dart counterparts. Unit tests only, so junit
    // never reaches the APK.
    testImplementation("junit:junit:4.13.2")

    // The android.jar on a local unit test classpath is a stub whose org.json
    // methods throw, which would make every alarm test fail for a reason that
    // has nothing to do with the alarm code. This puts a real implementation in
    // front of the stub. Test only; the APK still uses the platform's.
    testImplementation("org.json:json:20231013")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
