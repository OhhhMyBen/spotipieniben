allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    plugins.withId("com.android.library") {
        val android = extensions.findByName("android") as? com.android.build.gradle.LibraryExtension
        if (android != null && android.namespace == null) {
            val manifestFile = file("src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val manifestText = manifestFile.readText()
                val match = Regex("package\\s*=\\s*\"([^\"]+)\"").find(manifestText)
                if (match != null) {
                    android.namespace = match.groupValues[1]
                }
            }
        }
        extensions.findByType(com.android.build.api.variant.LibraryAndroidComponentsExtension::class.java)?.finalizeDsl { ext ->
            if ((ext.compileSdk ?: 0) < 34) {
                ext.compileSdk = 37
            }
        }
        afterEvaluate {
            val ext = extensions.findByName("android") as? com.android.build.gradle.LibraryExtension
            val javaCompat = ext?.compileOptions?.sourceCompatibility ?: JavaVersion.VERSION_11
            val target = when (javaCompat) {
                JavaVersion.VERSION_1_8 -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                JavaVersion.VERSION_11 -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                JavaVersion.VERSION_17 -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
            }
            tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
                compilerOptions.jvmTarget.set(target)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
