/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import android.util.Log
import assertk.assertThat
import assertk.assertions.isEqualTo
import assertk.assertions.isFalse
import assertk.assertions.isNotNull
import assertk.assertions.isNull
import assertk.assertions.isTrue
import com.datadog.android.DatadogSite
import com.datadog.android.core.configuration.BatchSize
import com.datadog.android.core.configuration.Credentials
import com.datadog.android.core.configuration.UploadFrequency
import com.datadog.android.privacy.TrackingConsent
import fr.xgouchet.elmyr.annotation.FloatForgery
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
        val verbose = parseVerbosity("Verbosity.verbose")
        val debug = parseVerbosity("Verbosity.debug")
        val info = parseVerbosity("Verbosity.info")
        val warn = parseVerbosity("Verbosity.warn")
        val error = parseVerbosity("Verbosity.error")
        val none = parseVerbosity("Verbosity.none")
        val unknown = parseVerbosity("unknown")

        assertThat(verbose).isEqualTo(Log.VERBOSE)
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
            "telemetrySampleRate" to null,
            "customEndpoint" to null,
            "firstPartyHosts" to listOf<String>(),
            "rumConfiguration" to null,
            "additionalConfig" to mapOf<String, Any?>()
        )

        // WHEN
        val config = DatadogFlutterConfiguration(encoded)

        // THEN
        assertThat(config.clientToken).isEqualTo(clientToken)
        assertThat(config.env).isEqualTo(environment)
        assertThat(config.trackingConsent).isEqualTo(TrackingConsent.GRANTED)

        assertThat(config.rumConfiguration).isNull()
    }

    @Test
    @Suppress("LongParameterList")
    fun `M decode all properties W fromEncoded`(
        @StringForgery clientToken: String,
        @StringForgery environment: String,
        @StringForgery additionalKey: String,
        @StringForgery additionalValue: String,
        @StringForgery firstPartyHost: String,
        @FloatForgery telemetrySampleRate: Float
    ) {
        // GIVEN
        val encoded = mapOf<String, Any?>(
            "clientToken" to clientToken,
            "env" to environment,
            "nativeCrashReportEnabled" to true,
            "serviceName" to null,
            "site" to "DatadogSite.us3",
            "batchSize" to "BatchSize.small",
            "uploadFrequency" to "UploadFrequency.frequent",
            "trackingConsent" to "TrackingConsent.granted",
            "telemetrySampleRate" to telemetrySampleRate,
            "customEndpoint" to "customEndpoint",
            "firstPartyHosts" to listOf(firstPartyHost),
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
        assertThat(config.telemetrySampleRate).isEqualTo(telemetrySampleRate)
        assertThat(config.additionalConfig).isEqualTo(mapOf(
            additionalKey to additionalValue
        ))
        assertThat(config.firstPartyHosts).isEqualTo(listOf(firstPartyHost))
    }

    @Test
    @Suppress("LongParameterList")
    fun `M decode serviceName W fromEncoded`(
        @StringForgery clientToken: String,
        @StringForgery environment: String,
        @StringForgery additionalKey: String,
        @StringForgery additionalValue: String,
        @StringForgery firstPartyHost: String,
        @StringForgery serviceName: String,
    ) {
        // GIVEN
        val encoded = mapOf<String, Any?>(
            "clientToken" to clientToken,
            "env" to environment,
            "nativeCrashReportEnabled" to true,
            "serviceName" to serviceName,
            "site" to "DatadogSite.us3",
            "batchSize" to "BatchSize.small",
            "uploadFrequency" to "UploadFrequency.frequent",
            "trackingConsent" to "TrackingConsent.granted",
            "customEndpoint" to "customEndpoint",
            "firstPartyHosts" to listOf(firstPartyHost),
            "rumConfiguration" to null,
            "additionalConfig" to mapOf<String, Any?>(
                additionalKey to additionalValue
            )
        )

        // WHEN
        val config = DatadogFlutterConfiguration(encoded)

        // THEN
        assertThat(config.serviceName).isEqualTo(serviceName)
    }

    @Test
    fun `M decode nestedConfiguration W fromEncoded {rumConfiguration}`(
        @StringForgery clientToken: String,
        @StringForgery environment: String,
        @StringForgery applicationId: String,
        @StringForgery firstPartyHost: String
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
            "firstPartyHosts" to listOf<String>(),
            "rumConfiguration" to mapOf(
                "applicationId" to applicationId,
                "sampleRate" to 35.0f
            ),
            "additionalConfig" to mapOf<String, Any?>()
        )

        // WHEN
        val config = DatadogFlutterConfiguration(encoded)

        // THEN
        assertThat(config.rumConfiguration).isNotNull()
        assertThat(config.rumConfiguration?.applicationId).isEqualTo(applicationId)
        assertThat(config.rumConfiguration?.sampleRate).isEqualTo(35.0f)
    }

    @Test
    fun `M decode LoggingConfiguration W LoggingConfiguration fromEncoded`() {
        // GIVEN
        val encoded = mapOf(
            "sendNetworkInfo" to true,
            "printLogsToConsole" to true,
            "sendLogsToDatadog" to false,
            "bundleWithRum" to true,
            "loggerName" to "my_logger"
        )

        // WHEN
        val config = LoggingConfiguration(encoded)

        // THEN
        assertThat(config.sendNetworkInfo).isTrue()
        assertThat(config.printLogsToConsole).isTrue()
        assertThat(config.sendLogsToDatadog).isFalse()
        assertThat(config.bundleWithRum).isTrue()
        assertThat(config.loggerName).isEqualTo("my_logger")
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
            serviceName = serviceName,
            nativeCrashReportEnabled = true,
            trackingConsent = TrackingConsent.PENDING,
            rumConfiguration = DatadogFlutterConfiguration.RumConfiguration(
                applicationId = applicationId,
                sampleRate = 100.0f
            ),
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