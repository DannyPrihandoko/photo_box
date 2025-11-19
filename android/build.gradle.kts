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

// --- BLOK subprojects TUNGGAL YANG MENGANDUNG SEMUA PATCH ---
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // Pastikan :app dievaluasi terlebih dahulu
    project.evaluationDependsOn(":app")

    // Patch untuk masalah Namespace DAN JVM Target
    project.afterEvaluate {
        // 1. PATCH UNTUK NAMESPACE (Berlaku global untuk semua package lama)
        if (project.plugins.hasPlugin("com.android.library")) {
            try {
                val android = project.extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
                if (android != null && android.namespace == null) {
                    // Mengatur namespace default untuk package lama
                    android.namespace = project.group.toString()
                }
            } catch (e: Exception) {
                println("Peringatan: Gagal mengkonfigurasi namespace untuk ${project.name}: ${e.message}")
            }
        }

        // 2. PATCH JVM (JAVA 1.8) HANYA UNTUK 'image_gallery_saver'
        if (project.name == "image_gallery_saver") {
            if (project.plugins.hasPlugin("com.android.library")) {
                val android = project.extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
                if (android != null) {
                    android.compileOptions {
                        sourceCompatibility = JavaVersion.VERSION_1_8
                        targetCompatibility = JavaVersion.VERSION_1_8
                    }
                }
            }
        }
    } // --- Akhir afterEvaluate ---

    // 3. PATCH KOTLIN JVM (JAVA 1.8) HANYA UNTUK 'image_gallery_saver'
    // Diterapkan saat plugin Kotlin dimuat (di luar afterEvaluate)
    if (project.name == "image_gallery_saver") {
        project.plugins.withId("org.jetbrains.kotlin.android") {
            // Konfigurasi Kotlin secara eksplisit
            project.extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinJvmOptions> {
                jvmTarget = "1.8"
            }
        }
    }
}
// --- AKHIR BLOK subprojects ---

// Blok 'subprojects' yang duplikat di bawah ini sudah digabungkan ke atas
// subprojects {
//     project.evaluationDependsOn(":app")
// }

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

