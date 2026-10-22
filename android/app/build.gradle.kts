import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key lives outside git, in android/key.properties (see RELEASE.md).
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val signingPropertyNames = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val signingProperties = signingPropertyNames.associateWith {
    keystoreProperties.getProperty(it)?.trim().orEmpty()
}
val signingIssue = when {
    signingProperties.values.all(String::isEmpty) -> "android/key.properties is missing"
    signingProperties.values.any(String::isEmpty) ->
        "android/key.properties is missing ${signingProperties.filterValues(String::isEmpty).keys.joinToString()}"
    !file(signingProperties.getValue("storeFile")).isFile ->
        "Android upload keystore does not exist: ${signingProperties.getValue("storeFile")}"
    else -> null
}
// Deliberately exact: a release build can use the debug key only when a local
// developer explicitly passes -PallowDebugSigning=true.
val allowDebugSigning = providers.gradleProperty("allowDebugSigning").orNull == "true"

android {
    namespace = "com.shivapps.numory"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications needs core library desugaring.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.shivapps.numory"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingIssue == null) {
            create("release") {
                keyAlias = signingProperties.getValue("keyAlias")
                keyPassword = signingProperties.getValue("keyPassword")
                storeFile = file(signingProperties.getValue("storeFile"))
                storePassword = signingProperties.getValue("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
                ?: if (allowDebugSigning) signingConfigs.getByName("debug")
                else null
        }
    }
}

// Validate only when release tasks are requested. A fresh checkout must still
// be able to compile debug builds without access to the private upload key.
gradle.taskGraph.whenReady {
    if (signingIssue != null && !allowDebugSigning &&
        allTasks.any { it.project == project && it.name.endsWith("Release") }) {
        throw GradleException(
            "Release signing is required: $signingIssue. " +
                "For a local-only debug-signed release build, pass -PallowDebugSigning=true.",
        )
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // PlayGamesSdk.initialize in MainActivity; same version as games_services.
    implementation("com.google.android.gms:play-services-games-v2:21.0.0")
}
