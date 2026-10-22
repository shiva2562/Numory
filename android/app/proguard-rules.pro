# Release-only R8 rules; the Flutter Gradle plugin adds this file to release builds.

# AdMob pulls in WorkManager 2.7.0 with Room 2.2.5. Room builds WorkDatabase_Impl by
# reflection (Class.newInstance), but its own rule keeps the class without its
# constructor, so R8 full mode strips it and every release launch crashes in
# androidx.startup.InitializationProvider ("Failed to create an instance of
# androidx.work.impl.WorkDatabase"). Play rejected ZipTrail build 5 for this.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
