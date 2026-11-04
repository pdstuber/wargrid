plugins {
    kotlin("jvm") version "2.2.20"
    kotlin("plugin.serialization") version "2.2.20"
    id("io.ktor.plugin") version "3.6.1"
}

repositories { mavenCentral() }

kotlin { jvmToolchain(21) }

application { mainClass.set("wargrid.relay.MainKt") }

ktor { fatJar { archiveFileName.set("relay-all.jar") } }

dependencies {
    implementation("io.ktor:ktor-server-cio")
    implementation("io.ktor:ktor-server-websockets")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")
    implementation("ch.qos.logback:logback-classic:1.5.18")
    testImplementation("io.ktor:ktor-server-test-host")
    testImplementation("io.ktor:ktor-client-websockets")
    testImplementation(kotlin("test"))
}
