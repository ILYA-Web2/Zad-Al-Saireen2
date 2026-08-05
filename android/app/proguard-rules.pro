
# Flutter Deferred Components / Play Core R8 fix
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# ── audio_service ────────────────────────────────────────────────────────
# The Service and BroadcastReceiver declared in AndroidManifest.xml
# (com.ryanheise.audioservice.AudioService / MediaButtonReceiver) are only
# ever instantiated by the Android OS via reflection from that manifest
# entry — R8 has no static call site to see, so with minifyEnabled true it
# can strip or rename them entirely. That leaves AudioService.init()'s
# platform-channel handshake in main() unable to complete, which — since
# runApp() is awaited after it — is what produces a permanently black,
# unresponsive first screen in release builds only (debug builds skip R8
# entirely, so this never reproduces from the IDE).
-keep class com.ryanheise.audioservice.** { *; }
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver
-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }

# ── just_audio ───────────────────────────────────────────────────────────
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# ── Supabase / websocket / JSON serialization ───────────────────────────
-keep class io.supabase.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn org.java_websocket.**
