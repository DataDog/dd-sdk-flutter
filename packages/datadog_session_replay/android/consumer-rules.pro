-keep class com.datadoghq.flutter.sessionreplay.** { *; }
-keep class com.datadog.android.api.feature.FeatureSdkCore** { *; }

# The native Session Replay module is optional in pure-Flutter applications.
-dontwarn com.datadog.android.sessionreplay._SessionReplayInternalProxy
-dontwarn com.datadog.android.sessionreplay._SessionReplayInternalProxy$Companion
