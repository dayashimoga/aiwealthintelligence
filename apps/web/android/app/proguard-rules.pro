# ============================================================
# WealthAI — ProGuard / R8 Rules
# ============================================================

# ── Flutter ──────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ── Kotlin ───────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**

# ── OkHttp / Dio (via dart:io JNI) ───────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**

# ── Local Auth (BiometricPrompt) ─────────────────────────
-keep class androidx.biometric.** { *; }
-keep class android.hardware.fingerprint.** { *; }

# ── Flutter Secure Storage ────────────────────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ── Google Fonts / Material ───────────────────────────────
-keep class com.google.** { *; }

# ── WebSocket (web_socket_channel) ───────────────────────
-dontwarn org.codehaus.mojo.animal_sniffer.**

# ── Gson / JSON serialization ────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

# ── General Android safety ───────────────────────────────
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
-keepclassmembers class * implements java.io.Serializable {
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
