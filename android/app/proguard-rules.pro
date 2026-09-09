# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
# sqflite / TTS / printing use reflection lightly
-keep class com.tekartik.sqflite.** { *; }
-keep class net.nfet.flutter.printing.** { *; }
-keep class com.tundralabs.fluttertts.** { *; }
# Google Sign-In / Drive
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
