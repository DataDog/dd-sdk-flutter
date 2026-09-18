/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.forge

import com.datadog.android.DatadogSite
import com.datadog.android.api.context.DatadogContext
import com.datadog.android.api.context.DeviceInfo
import com.datadog.android.api.context.DeviceType
import com.datadog.android.api.context.LocaleInfo
import com.datadog.android.api.context.NetworkInfo
import com.datadog.android.api.context.ProcessInfo
import com.datadog.android.api.context.TimeInfo
import com.datadog.android.api.context.UserInfo
import com.datadog.android.privacy.TrackingConsent
import fr.xgouchet.elmyr.Forge
import fr.xgouchet.elmyr.ForgeryFactory
import java.util.Locale
import java.util.UUID

class DatadogContextForgeryFactory : ForgeryFactory<DatadogContext> {
    @Suppress("LongMethod")
    override fun getForgery(forge: Forge): DatadogContext {
        return DatadogContext(
            site = forge.aValueFrom(DatadogSite::class.java),
            clientToken = forge.anHexadecimalString().lowercase(Locale.US),
            service = forge.anAlphabeticalString(),
            version = forge.aStringMatching("[0-9](\\.[0-9]{1,3}){2,3}"),
            versionCode = forge.anInt(),
            variant = forge.anAlphabeticalString(),
            env = forge.anAlphabeticalString().lowercase(Locale.US),
            source = forge.anAlphabeticalString(),
            sdkVersion = forge.aStringMatching("[0-9](\\.[0-9]{1,2}){1,3}"),
            time = TimeInfo(
                deviceTimeNs = forge.aLong(min = 0),
                serverTimeNs = forge.aLong(min = 0),
                serverTimeOffsetNs = forge.aLong(),
                serverTimeOffsetMs = forge.aLong()
            ),
            processInfo = ProcessInfo(isMainProcess = forge.aBool()),
            networkInfo = NetworkInfo(
                connectivity = forge.aValueFrom(NetworkInfo.Connectivity::class.java),
                carrierName = forge.anElementFrom(
                    forge.anAlphabeticalString(),
                    forge.aWhitespaceString(),
                    null
                ),
                carrierId = forge.aNullable { aLong(0, 10000) },
                upKbps = forge.aNullable { aLong(1, Long.MAX_VALUE) },
                downKbps = forge.aNullable { aLong(1, Long.MAX_VALUE) },
                strength = forge.aNullable { aLong(-100, -30) }, // dBm for wifi signal
                cellularTechnology = forge.aNullable { anAlphabeticalString() }
            ),
            deviceInfo = DeviceInfo(
                deviceName = forge.anAlphabeticalString(),
                deviceBrand = forge.anAlphabeticalString(),
                deviceModel = forge.anAlphabeticalString(),
                deviceType = forge.aValueFrom(DeviceType::class.java),
                deviceBuildId = forge.anAlphaNumericalString(),
                osName = forge.aString(),
                osVersion = forge.aString(),
                osMajorVersion = forge.aString(),
                architecture = forge.aString(),
                numberOfDisplays = forge.aNullable { anInt() },
                localeInfo = LocaleInfo(
                    locales = forge.aList { forge.aString() },
                    currentLocale = forge.aString(),
                    timeZone = forge.aString()
                ),
                logicalCpuCount = forge.anInt(),
                totalRam = forge.anInt(),
                isLowRam = forge.aBool()
            ),
            userInfo = UserInfo(
                id = forge.aNullable { anHexadecimalString() },
                name = forge.aNullable {
                    aStringMatching("[A-Z][a-z]+ [A-Z]\\. [A-Z][a-z]+")
                },
                email = forge.aNullable {
                    aStringMatching("[a-z]+\\.[a-z]+@[a-z]+\\.[a-z]{3}")
                },
                additionalProperties = mapOf()
            ),
            trackingConsent = forge.aValueFrom(TrackingConsent::class.java),
            appBuildId = forge.aNullable { getForgery<UUID>().toString() },
            accountInfo = null,
            // building nested maps with default size slows down tests quite a lot, so will use
            // an explicit small size
            featuresContext = mapOf()
        )
    }
}
