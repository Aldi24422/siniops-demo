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
    project.evaluationDependsOn(":app")
}

// Fix for deprecated package attribute in plugins
// This must run when the Android library plugin is applied, before manifest processing
subprojects {
    plugins.withType<com.android.build.gradle.LibraryPlugin> {
        when (project.name) {
            "flutter_notification_listener" -> {
                extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
                    namespace = "im.zoe.labs.flutter_notification_listener"
                }
            }
            "blue_thermal_printer" -> {
                extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
                    namespace = "id.kakzaki.blue_thermal_printer"
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
