package com.datadoghq.hybrid_flutter_example

import android.app.Application
import android.util.Log
import com.datadog.android.Datadog
import com.datadog.android.DatadogSite
import com.datadog.android.core.configuration.BatchSize
import com.datadog.android.core.configuration.Configuration
import com.datadog.android.core.configuration.Credentials
import com.datadog.android.core.configuration.UploadFrequency
import com.datadog.android.privacy.TrackingConsent
import com.datadog.android.rum.GlobalRum
import com.datadog.android.rum.RumMonitor
import org.json.JSONObject

class HybridApplication : Application() {
    private val TAG = "HybridApplication"

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
            logsEnabled = true,
            tracesEnabled = true,
            crashReportsEnabled = true,
            rumEnabled = true,
        )
            .setBatchSize(BatchSize.SMALL)
            .setUploadFrequency(UploadFrequency.FREQUENT)
            .useSite(DatadogSite.US1)
            .trackInteractions()
            .trackLongTasks()
            .build()

        val datadogCredentials = Credentials(clientToken, "prod", "release", applicationId)

        Datadog.initialize(
            this,
            credentials = datadogCredentials,
            configuration = datadogConfig,
            TrackingConsent.GRANTED
        )

        val monitor = RumMonitor.Builder().build()
        GlobalRum.registerIfAbsent(monitor)
    }
}
