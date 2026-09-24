plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.eri.deltabypass"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.eri.deltabypass"
        minSdk = 29
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    // MIUIX 官方坐标（HyperOS 风格组件库）
    implementation("top.yukonga.miuix.kmp:miuix-ui-android:0.9.4")
    // 扩展图标库：NavigationBarItem / 复制按钮图标需要
    implementation("top.yukonga.miuix.kmp:miuix-icons-android:0.9.4")
    // ComponentActivity + setContent + enableEdgeToEdge（与 miuix 官方 example 相同版本）
    implementation("androidx.activity:activity-compose:1.13.0")
}