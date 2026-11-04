plugins {
    kotlin("jvm") version "2.2.20"
    kotlin("plugin.serialization") version "2.2.20"
    id("io.ktor.plugin") version "3.6.1"
    id("org.graalvm.buildtools.native") version "0.11.3"
}

repositories { mavenCentral() }

kotlin { jvmToolchain(21) }

application { mainClass.set("wargrid.relay.MainKt") }

ktor { fatJar { archiveFileName.set("relay-all.jar") } }

graalvmNative {
    binaries.named("main") {
        imageName.set("relay")
        buildArgs.addAll(
            "--initialize-at-build-time=ch.qos.logback,io.ktor,kotlin,org.slf4j.LoggerFactory,org.slf4j.helpers.Reporter,kotlinx.io.bytestring.ByteString,kotlinx.io.SegmentPool,kotlinx.serialization.json.Json,kotlinx.serialization.json.JsonImpl,kotlinx.serialization.json.ClassDiscriminatorMode,kotlinx.serialization.modules.SerializersModuleKt",
            "--initialize-at-run-time=kotlinx.coroutines,kotlinx.io.files,io.ktor.utils.io.jvm.javaio", "-H:+InstallExitHandlers", "-H:+ReportUnsupportedElementsAtRuntime", "-H:+ReportExceptionStackTraces",
        )
    }
}

dependencies {
    implementation("io.ktor:ktor-server-cio")
    implementation("io.ktor:ktor-server-websockets")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")
    implementation("ch.qos.logback:logback-classic:1.5.18")
    testImplementation("io.ktor:ktor-server-test-host")
    testImplementation("io.ktor:ktor-client-websockets")
    testImplementation(kotlin("test"))
}
