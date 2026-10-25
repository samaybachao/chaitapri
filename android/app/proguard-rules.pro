# Extra R8 / ProGuard rules for the release build (Flutter adds this file automatically).
#
# Why: the Google Mobile Ads SDK pulls in AndroidX WorkManager, which stores its jobs in a
# Room database that is created by reflection (WorkDatabase_Impl). Without these rules R8
# removes the constructor and the app crashes at start-up with
#   "Failed to create an instance of androidx.work.impl.WorkDatabase".

# Room: keep every generated database implementation and its no-argument constructor.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.WorkDatabase { *; }

# WorkManager: workers are created by reflection from their class name.
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class androidx.work.impl.** { *; }
-dontwarn androidx.work.**
