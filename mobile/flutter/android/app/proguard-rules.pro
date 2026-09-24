# SmartFlow ProGuard Rules for Release Builds

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep Provider classes
-keep class * extends androidx.lifecycle.ViewModel
-keep class * extends androidx.lifecycle.AndroidViewModel

# Keep data classes
-keep class com.urbiztondo.smartflow.** { *; }

# Keep JSON serialization classes
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn okhttp3.**
-dontwarn retrofit2.**

# Keep mobile scanner
-keep class com.google.mlkit.** { *; }
-keep class androidx.camera.** { *; }
