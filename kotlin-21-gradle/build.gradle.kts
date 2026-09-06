plugins {
    kotlin("jvm") version "2.0.21"
    id("com.autonomousapps.dependency-analysis") version "1.31.0"
    id("com.github.ben-manes.versions") version "0.51.0"
}

repositories {
    mavenCentral()
}

java {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
    }
}

dependencies {
    // Active Dependency: Used in App.kt
    implementation("org.slf4j:slf4j-api:2.0.12")

    // Unused Dependency: Attack Surface Reduction Test Fixture
    implementation("com.google.code.gson:gson:2.10.1")

    // Outdated / Major Lag Dependency: Dependency Lifecycle Test Fixture
    implementation("com.fasterxml.jackson.core:jackson-databind:2.9.10")

    // Vulnerable Dependency (High/Critical CVEs): Direct CVE Scan Test Fixture
    implementation("ch.qos.logback:logback-core:1.2.3")
}

dependencyAnalysis {
    issues {
        all {
            onUnusedDependencies {
                severity("warn")
            }
        }
    }
}

fun isNonStable(version: String): Boolean {
    val stableKeyword = listOf("RELEASE", "FINAL", "GA").any { version.uppercase().contains(it) }
    val regex = "^[0-9,.v-]+(-r)?$".toRegex()
    val isStable = stableKeyword || regex.matches(version)
    return !isStable
}

tasks.named<com.github.benmanes.gradle.versions.updates.DependencyUpdatesTask>("dependencyUpdates").configure {
    rejectVersionIf {
        isNonStable(candidate.version)
    }
}
