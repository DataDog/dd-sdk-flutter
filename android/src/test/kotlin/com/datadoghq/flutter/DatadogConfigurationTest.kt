/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import android.util.Log
import assertk.assertThat
import assertk.assertions.isEqualTo
import assertk.assertions.isNotNull
import assertk.assertions.isNull
import com.datadog.android.DatadogSite
import com.datadog.android.core.configuration.BatchSize
import com.datadog.android.core.configuration.Credentials
import com.datadog.android.core.configuration.UploadFrequency
import com.datadog.android.privacy.TrackingConsent
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith

@ExtendWith(ForgeExtension::class)
class DatadogConfigurationTest {
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

    @Test
    fun `M parse all Verbosity W parseVerbosity`() {
        // WHEN
        val debug = parseVerbosity("Verbosity.debug")
        val info = parseVerbosity("Verbosity.info")
        val warn = parseVerbosity("Verbosity.warn")
        val error = parseVerbosity("Verbosity.error")
        val none = parseVerbosity("Verbosity.none")
        val unknown = parseVerbosity("unknown")

        assertThat(debug).isEqualTo(Log.DEBUG)
        assertThat(info).isEqualTo(Log.INFO)
        assertThat(warn).isEqualTo(Log.WARN)
        assertThat(error).isEqualTo(Log.ERROR)
        assertThat(none).isEqualTo(Int.MAX_VALUE)
        assertThat(unknown).isEqualTo(Int.MAX_VALUE)
    }

    @Test
    fun `M decode defaults W fromEncoded`(
        @StringForgery clientToken: String,
        @StringForgery environment: String
    ) {
        // GIVEN
        val encoded = mapOf<String, Any?>(
            "clientToken" to clientToken,
            "env" to environment,
            "nativeCrashReportEnabled" to false,
            "site" to null,
            "batchSize" to null,
            "uploadFrequency" to null,
            "trackingConsent" to "TrackingConsent.granted",
            "customEndpoint" to null,
            "loggingConfiguration" to null,
            "tracingConfiguration" to null,
            "rumConfiguration" to null,
            "additionalConfig" to mapOf<String, Any?>()
        )

        // WHEN
        val config = DatadogFlutterConfiguration(encoded)

        // THEN
        assertThat(config.clientToken).isEqualTo(clientToken)
        assertThat(config.env).isEqualTo(environment)
        assertThat(config.trackingConsent).isEqualTo(TrackingConsent.GRANTED)

        assertThat(config.loggingConfiguration).isNull()
        assertThat(config.tracingConfiguration).isNull()
        assertThat(config.rumConfiguration).isNull()
    }

    @Test
    fun `M decode all properties W fromEncoded`(
        @StringForgery clientToken: String,
        @StringForgery environment: String,
        @StringForgery additionalKey: String,
        @StringForgery additionalValue: String
    ) {
        // GIVEN
        val encoded = mapOf<String, Any?>(
            "clientToken" to clientToken,
            "env" to environment,
            "nativeCrashReportEnabled" to true,
            "site" to "DatadogSite.us3",
            "batchSize" to "BatchSize.small",
            "uploadFrequency" to "UploadFrequency.frequent",
            "trackingConsent" to "TrackingConsent.granted",
            "customEndpoint" to "customEndpoint",
            "loggingConfiguration" to null,
            "tracingConfiguration" to null,
            "rumConfiguration" to null,
            "additionalConfig" to mapOf<String, Any?>(
                additionalKey to additionalValue
            )
        )

        // WHEN
        val config = DatadogFlutterConfiguration(encoded)

        // THEN
        assertThat(config.nativeCrashReportEnabled).isEqualTo(true)
        assertThat(config.site).isEqualTo(DatadogSite.US3)
        assertThat(config.batchSize).isEqualTo(BatchSize.SMALL)
        assertThat(config.customEndpoint).isEqualTo("customEndpoint")
        assertThat(config.additionalConfig).isEqualTo(mapOf(
            additionalKey to additionalValue
        ))
    }

    @Test
    fun `M decode nestedConfiguration W fromEncoded {loggingConfiguration, tracingConfiguration, rumConfiguration}`(
        @StringForgery clientToken: String,
        @StringForgery environment: String,
        @StringForgery applicationId: String
    ) {
        // GIVEN
        val encoded = mapOf(
            "clientToken" to clientToken,
            "env" to environment,
            "nativeCrashReportEnabled" to false,
            "site" to null,
            "batchSize" to null,
            "uploadFrequency" to null,
            "trackingConsent" to "TrackingConsent.pending",
            "customEndpoint" to null,
            "loggingConfiguration" to mapOf(
                "sendNetworkInfo" to true,
                "printLogsToConsole" to true
            ),
            "tracingConfiguration" to mapOf(
                "sendNetworkInfo" to true,
                "bundleWithRum" to false,
            ),
            "rumConfiguration" to mapOf(
                "applicationId" to applicationId,
                "sampleRate" to 35.0f
            ),
            "additionalConfig" to mapOf<String, Any?>()
        )

        // WHEN
        val config = DatadogFlutterConfiguration(encoded)

        // THEN
        assertThat(config.loggingConfiguration).isNotNull()
        assertThat(config.loggingConfiguration?.sendNetworkInfo).isEqualTo(true)
        assertThat(config.loggingConfiguration?.printLogsToConsole).isEqualTo(true)

        assertThat(config.tracingConfiguration).isNotNull()
        assertThat(config.tracingConfiguration?.sendNetworkInfo).isEqualTo(true)
        assertThat(config.tracingConfiguration?.bundleWithRum).isEqualTo(false)

        assertThat(config.rumConfiguration).isNotNull()
        assertThat(config.rumConfiguration?.applicationId).isEqualTo(applicationId)
        assertThat(config.rumConfiguration?.sampleRate).isEqualTo(35.0f)
    }

    @Test
    fun `M build correct credentials W calling DatadogFlutterConfiguration toCredentials`(
        @StringForgery clientToken: String,
        @StringForgery env: String,
        @StringForgery applicationId: String,
        @StringForgery serviceName: String,
    ) {
        // GIVEN
        val config = DatadogFlutterConfiguration(
            clientToken = clientToken,
            env = env,
            nativeCrashReportEnabled = true,
            trackingConsent = TrackingConsent.PENDING,
            rumConfiguration = DatadogFlutterConfiguration.RumConfiguration(
                applicationId = applicationId,
                sampleRate = 100.0f
            ),
            additionalConfig = mapOf<String, Any?>(
                "_dd.service_name" to serviceName
            )
        )

        // WHEN
        val credentials = config.toCredentials()

        // THEN
        val expectedCredentials = Credentials(
            clientToken = clientToken,
            envName = env,
            rumApplicationId = applicationId,
            variant = Credentials.NO_VARIANT,
            serviceName = serviceName
        )

        assertThat(credentials).isEqualTo(expectedCredentials)
    }
}