# R8 / ProGuard rules for release builds.
#
# Why this file has to exist: Flutter's Gradle plugin turns on `minifyEnabled`
# and `shrinkResources` for every release build, and it only feeds R8 the keep
# rules for the Flutter engine itself. Plugin code is fair game. Debug builds
# skip R8 entirely, which is exactly why "works when I run it, silently dead in
# the APK" is the classic shape of this bug.
#
# Nothing here affects Dart code — that is AOT compiled and never touched by R8.

# --- flutter_local_notifications ---------------------------------------------
# A scheduled reminder is handed to Android's AlarmManager and comes back much
# later, often with no Dart isolate alive. The plugin rebuilds the notification
# in Java at that moment, from a copy it serialised to disk with Gson. If R8 has
# renamed the fields of those model classes, or dropped the generic signatures
# Gson reflects on, deserialisation fails inside the broadcast receiver and the
# notification simply never appears. No crash, no log in the app — the alarm
# fires into a void. Keeping the whole package is the cheap, safe answer.
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.models.** { *; }

# The receivers below are named as strings in AndroidManifest.xml, so R8 keeps
# the classes, but be explicit about their no-arg constructors: Android
# instantiates them reflectively.
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver { <init>(...); }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver { <init>(...); }
-keep class com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver { <init>(...); }
-keep class com.dexterous.flutterlocalnotifications.ForegroundService { <init>(...); }

# --- Gson --------------------------------------------------------------------
# Reflection-driven, so it needs its metadata preserved. Signature in
# particular: without it a List<T> field decodes as a raw List and throws.
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes *Annotation*
-dontwarn com.google.gson.**
-keep class com.google.gson.reflect.TypeToken { *; }
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-keep class * implements com.google.gson.TypeAdapter { *; }
-keep class * implements com.google.gson.TypeAdapterFactory { *; }
-keep class * implements com.google.gson.JsonSerializer { *; }
-keep class * implements com.google.gson.JsonDeserializer { *; }
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
# Enum constants are matched by name when Gson reads them back.
-keepclassmembers enum * {
  public static **[] values();
  public static ** valueOf(java.lang.String);
}

# --- java.time via core library desugaring -----------------------------------
# The scheduler reaches for java.time on minSdk 23 through desugar_jdk_libs.
-dontwarn java.time.**
-dontwarn sun.misc.**

# --- shared_preferences ------------------------------------------------------
# The background isolate writes the water/medicine log through this while the UI
# is gone, so its Android side has to survive shrinking too.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
