package com.datadoghq.hybrid_flutter_example

import android.app.Activity
import android.app.Application
import android.util.Log
import com.datadog.android.Datadog
import com.datadog.android.DatadogSite
import com.datadog.android.core.configuration.BatchSize
import com.datadog.android.core.configuration.Configuration
import com.datadog.android.core.configuration.UploadFrequency
import com.datadog.android.privacy.TrackingConsent
import com.datadog.android.rum.Rum
import com.datadog.android.rum.RumConfiguration
import com.datadog.android.rum.tracking.AcceptAllActivities
import com.datadog.android.rum.tracking.ActivityViewTrackingStrategy
import com.datadog.android.rum.tracking.ComponentPredicate
import com.datadog.android.trace.Trace
import com.datadog.android.trace.TraceConfiguration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import org.json.JSONObject

class FlutterExcludingComponentPredicate: ComponentPredicate<Activity> {
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

        val rumConfiguration = RumConfiguration.Builder(applicationId)
            .trackLongTasks()
            .trackUserInteractions()
            .useViewTrackingStrategy(ActivityViewTrackingStrategy(
                trackExtras = false,
                componentPredicate = FlutterExcludingComponentPredicate()
            ))
        Rum.enable(rumConfiguration.build())
        val traceConfig = TraceConfiguration.Builder()
        Trace.enable(traceConfig.build())

        flutterEngine = FlutterEngine(this)
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        FlutterEngineCache.getInstance().put("datadoghq_engine", flutterEngine)
    }
}
