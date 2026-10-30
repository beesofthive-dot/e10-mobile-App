import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing key (Play Store upload key). Lives outside the repo;
// android/key.properties points at it and is gitignored.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.e10.e10"
    compileSdk = 36  // Match the highest Android SDK required by the current plugins
    // Disable NDK to avoid download issues due to security policies
    // ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.e10.e10"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion  // Explicit version instead of flutter.minSdkVersion
        targetSdk = 36  // Match the compile SDK required by the plugin set
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Without key.properties (e.g. another machine) fall back to the
            // debug key so local release builds still work — those can't be
            // uploaded to Play.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
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

// Play's sensitive-permission policies block releases that declare these.
// AndroidManifest.xml strips them with tools:node="remove"; fail the release
// manifest task if a plugin update ever reintroduces one.
val bannedPermissions = listOf(
    "android.permission.READ_MEDIA_IMAGES",
    "android.permission.READ_MEDIA_VIDEO",
    "android.permission.READ_MEDIA_VISUAL_USER_SELECTED",
    "android.permission.READ_MEDIA_AUDIO",
    "android.permission.REQUEST_INSTALL_PACKAGES",
    "android.permission.MANAGE_EXTERNAL_STORAGE",
    "android.permission.READ_EXTERNAL_STORAGE",
    "android.permission.WRITE_EXTERNAL_STORAGE",
    "android.permission.QUERY_ALL_PACKAGES",
    "android.permission.READ_CONTACTS",
    "android.permission.READ_SMS",
    "android.permission.READ_CALL_LOG",
)
tasks.matching { it.name == "processReleaseManifest" }.configureEach {
    doLast {
        outputs.files.asFileTree.matching { include("**/AndroidManifest.xml") }.forEach { manifest ->
            val text = manifest.readText()
            val found = bannedPermissions.filter { text.contains("\"$it\"") }
            if (found.isNotEmpty()) {
                throw GradleException(
                    "Release manifest declares ${found.joinToString()}, which Google Play " +
                        "does not permit for this app. Add <uses-permission " +
                        "tools:node=\"remove\"> for it in " +
                        "android/app/src/main/AndroidManifest.xml.",
                )
            }
        }
    }
}
