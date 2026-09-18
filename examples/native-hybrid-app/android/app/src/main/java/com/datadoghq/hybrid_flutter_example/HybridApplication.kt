package com.datadoghq.hybrid_flutter_example

import android.app.Activity
import android.app.Application
import android.util.Log
import com.datadog.android.Datadog
import com.datadog.android.DatadogSite
import com.datadog.android.core.configuration.BatchSize
import com.datadog.android.core.configuration.Configuration
import com.datadog.android.core.configuration.UploadFrequency
import com.datadog.android.log.Logs
import com.datadog.android.log.LogsConfiguration
import com.datadog.android.privacy.TrackingConsent
import com.datadog.android.rum.Rum
import com.datadog.android.rum.RumConfiguration
import com.datadog.android.rum.tracking.AcceptAllActivities
import com.datadog.android.rum.tracking.ActivityViewTrackingStrategy
import com.datadog.android.rum.tracking.ComponentPredicate
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import org.json.JSONObject

/**
 * This [ComponentPredicate] excludes all [FlutterActivity]s from being tracked by RUM, so that
 * the Flutter SDK can handle them instead.
 */
class FlutterExcludingComponentPredicate : ComponentPredicate<Activity> {
    val innerPredicate = AcceptAllActivities()

    override fun accept(component: Activity): Boolean {
        if (component is FlutterActivity) {
            return false
        }

        return innerPredicate.accept(component)
    }

    override fun getViewName(component: Activity): String? {
        return innerPredicate.getViewName(component)
    }
}

class HybridApplication : Application() {
    private val TAG = "HybridApplication"
    private lateinit var flutterEngine: FlutterEngine

    override fun onCreate() {
        super.onCreate()

        var clientToken = ""
        var applicationId = ""
        try {
            val jsonText = resources.openRawResource(R.raw.dd_config).bufferedReader().use {
                it.readText()
            }
            val config = JSONObject(jsonText)
            clientToken = config.get("client_token") as String
            applicationId = config.get("application_id") as String
        } catch (e: Exception) {
            Log.e(
                TAG,
                "Failed to find client token and application id in raw/dd_config.json." +
                    " Did you run './generate_env'?",
                e
            )
        }

        Datadog.setVerbosity(Log.VERBOSE)

        // If you are adding Flutter to an existing Android application, you should
        // ensure Datadog is fully initialized on the Android side before
        // initializing Flutter and calling `DatadogSdk.attachToExisting`.
        // For more information about how to setup Datadog in Android, see the official
        // documentation:
        // https://docs.datadoghq.com/real_user_monitoring/mobile_and_tv_monitoring/android/setup
        val datadogConfig = Configuration.Builder(
            clientToken,
            "prod",
            "release"
        )
            .setBatchSize(BatchSize.SMALL)
            .setUploadFrequency(UploadFrequency.FREQUENT)
            .useSite(DatadogSite.US1)
            .build()

        Datadog.initialize(
            this,
            configuration = datadogConfig,
            TrackingConsent.GRANTED
        )

        // All components you want to use in Flutter must be initialized on iOS first.
        // This includes Logs...
        val logsConfiguration = LogsConfiguration.Builder()
            .build()
        Logs.enable(logsConfiguration)

        // ... RUM...
        val rumConfiguration = RumConfiguration.Builder(applicationId)
            .trackLongTasks()
            .trackUserInteractions()
            .useViewTrackingStrategy(
                ActivityViewTrackingStrategy(
                    trackExtras = false,
                    componentPredicate = FlutterExcludingComponentPredicate()
                )
            )
        Rum.enable(rumConfiguration.build())

        // ... and NDK crash reporting (this is optional. See documentation for more details).
        // https://docs.datadoghq.com/real_user_monitoring/mobile_and_tv_monitoring/android/error_tracking
        // NdkCrashReporting.enable()
        // Once Datadog is fully initialized, you can run `flutterEngine.run()`.
        // This calls Flutter's `main` method, which will look for an existing Datadog instance to attach to.
        flutterEngine = FlutterEngine(this)
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        FlutterEngineCache.getInstance().put("datadoghq_engine", flutterEngine)
    }
}
