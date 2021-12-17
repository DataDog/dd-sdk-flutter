package com.datadoghq.flutter

import com.datadog.android.core.configuration.Configuration
import assertk.assertThat
import assertk.assertions.*
import com.datadog.android.DatadogSite
import com.datadog.android.core.configuration.BatchSize
import com.datadog.android.core.configuration.Credentials
import com.datadog.android.core.configuration.UploadFrequency
import com.datadog.android.privacy.TrackingConsent
import org.junit.Test

class DatadogSdkPluginTest {

    @Test
    fun `M build correct credentials W buildCredentials`() {
        // GIVEN
        val configMap = hashMapOf<String, Any?>(
            "clientToken" to "fakeClientToken",
            "env" to "prod",
            "applicationId" to "applicationId",
            "sampleRate" to null,
            "site" to null,
            "trackingConsent" to "TrackingConsent.granted",
            "additionalConfig" to hashMapOf<String, Any?>(
                "_dd.service_name" to "serviceName"
            )
        )

        // WHEN
        val credentials = buildCredentials(configMap)

        // THEN
        val expectedCredentials = Credentials(
            clientToken = "fakeClientToken",
            envName = "prod",
            rumApplicationId = "applicationId",
            variant = Credentials.NO_VARIANT,
            serviceName = "serviceName"
        )

        assertThat(credentials).isEqualTo(expectedCredentials)
    }

    @Test
    fun `M parse all batch sizes W parseBatchSize`() {
        // WHEN
        val small = parseBatchSize("BatchSize.small")
        val medium = parseBatchSize("BatchSize.medium")
        val large = parseBatchSize("BatchSize.large")

        // THEN
        assertThat(small).isEqualTo(BatchSize.SMALL)
        assertThat(medium).isEqualTo(BatchSize.MEDIUM)
        assertThat(large).isEqualTo(BatchSize.LARGE)
    }

    @Test
    fun `M parse all upload frequency W parseUploadFrequency`() {
        // WHEN
        val frequent = parseUploadFrequency("UploadFrequency.frequent")
        val average = parseUploadFrequency("UploadFrequency.average")
        val rare = parseUploadFrequency("UploadFrequency.rare")

        // THEN
        assertThat(frequent).isEqualTo(UploadFrequency.FREQUENT)
        assertThat(average).isEqualTo(UploadFrequency.AVERAGE)
        assertThat(rare).isEqualTo(UploadFrequency.RARE)
    }

    @Test
    fun `M parse all tracking consent W parseTrackingConsent`() {
        // WHEN
        val granted = parseTrackingConsent("TrackingConsent.granted")
        val notGranted = parseTrackingConsent("TrackingConsent.notGranted")
        val pending = parseTrackingConsent("TrackingConsent.pending")

        // THEN
        assertThat(granted).isEqualTo(TrackingConsent.GRANTED)
        assertThat(notGranted).isEqualTo(TrackingConsent.NOT_GRANTED)
        assertThat(pending).isEqualTo(TrackingConsent.PENDING)
    }

    @Test
    fun `M parse all sites W parseSite`() {
        // WHEN
        val us1 = parseSite("DatadogSite.us1")
        val us3 = parseSite("DatadogSite.us3")
        val us5 = parseSite("DatadogSite.us5")
        val eu1 = parseSite("DatadogSite.eu1")
        val us1Fed = parseSite("DatadogSite.us1Fed")

        // THEN
        assertThat(us1).isEqualTo(DatadogSite.US1)
        assertThat(us3).isEqualTo(DatadogSite.US3)
        assertThat(us5).isEqualTo(DatadogSite.US5)
        assertThat(eu1).isEqualTo(DatadogSite.EU1)
        assertThat(us1Fed).isEqualTo(DatadogSite.US1_FED)
    }
}