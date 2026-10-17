import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase 설정 파일(사람이 넣는다, 커밋 안 함)이 없으면 플러그인 없이 빌드 → 앱에서 분석은 no-op.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
}

// 릴리스 서명: android/key.properties(커밋 안 함, docs/store/android-release.md). 없으면 debug 서명 + 경고.
val keyProperties =
    Properties().apply {
        val f = rootProject.file("key.properties")
        if (f.exists()) f.inputStream().use { load(it) }
    }
val hasReleaseKey = keyProperties.getProperty("storeFile") != null

android {
    namespace = "repo.dot.pirate"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 예약 알림
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "repo.dot.pirate"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 탑다운 시험판 빌드(-Pproto): 본 게임과 나란히 설치되게 다른 ID(덮어쓰지 않음 — 세이브 보존)
        if (project.hasProperty("proto")) applicationIdSuffix = ".proto"
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 네이티브 디버그 심볼은 함수 이름표만(SYMBOL_TABLE) — FULL이면 aab 안 BUNDLE-METADATA가 26MB(사용자에겐 안 내려가지만
            // 업로드·보관이 무겁다). Play·Crashlytics 네이티브 스택의 함수 이름은 그대로 나온다(docs/store/app-size.md).
            ndk.debugSymbolLevel = "SYMBOL_TABLE"
            // R8 예외 규칙(WorkManager의 Room 구현 클래스) — 없으면 릴리스가 실행 즉시 종료된다(proguard-rules.pro).
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig =
                if (hasReleaseKey) {
                    signingConfigs.getByName("release")
                } else {
                    logger.warn("경고: android/key.properties 없음 — 릴리스를 debug 키로 서명합니다(스토어 업로드 불가).")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
