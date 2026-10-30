# R8 keep rules for release builds.

# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# ML Kit (face + pose detection). The ML Kit artifacts reference optional
# modules (e.g. other-language text recognizers) the app doesn't include.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_** { *; }
-dontwarn com.google.mlkit.**

# LiveKit / WebRTC (JNI)
-keep class org.webrtc.** { *; }
-keep class livekit.** { *; }
-dontwarn org.webrtc.**

# Firebase / Google Sign-In
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-dontwarn com.google.android.play.core.**
