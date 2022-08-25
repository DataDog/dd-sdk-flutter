// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Foundation
import Datadog
import DatadogCrashReporting

class DatadogLoggingConfiguration {
    let sendNetworkInfo: Bool
    let printLogsToConsole: Bool
    let sendLogsToDatadog: Bool
    let bundleWithRum: Bool
    let loggerName: String?

    init(
        sendNetworkInfo: Bool = false,
        printLogsToConsole: Bool = false,
        sendLogsToDatadog: Bool = true,
        bundleWithRum: Bool = true,
        loggerName: String? = nil
    ) {
        self.sendNetworkInfo = sendNetworkInfo
        self.printLogsToConsole = printLogsToConsole
        self.sendLogsToDatadog = sendLogsToDatadog
        self.bundleWithRum = bundleWithRum
        self.loggerName = loggerName
    }

    init?(fromEncoded encoded: [String: Any?]) {
        sendNetworkInfo = (encoded["sendNetworkInfo"] as? NSNumber)?.boolValue ?? false
        printLogsToConsole = (encoded["printLogsToConsole"] as? NSNumber)?.boolValue ?? false
        sendLogsToDatadog = (encoded["sendLogsToDatadog"] as? NSNumber)?.boolValue ?? true
        bundleWithRum = (encoded["bundleWithRum"] as? NSNumber)?.boolValue ?? true
        loggerName = encoded["loggerName"] as? String
    }
}

class DatadogFlutterConfiguration {
    class RumConfiguration {
        let applicationId: String
        let sampleRate: Float

        init(applicationId: String, sampleRate: Float) {
            self.applicationId = applicationId
            self.sampleRate = sampleRate
        }

        init?(fromEncoded encoded: [String: Any?]) {
            do {
                applicationId = try castUnwrap(encoded["applicationId"])
            } catch {
                return nil
            }

            sampleRate = (encoded["sampleRate"] as? NSNumber)?.floatValue ?? 100.0
        }
    }

    let clientToken: String
    let env: String
    let serviceName: String?
    let nativeCrashReportingEnabled: Bool
    let trackingConsent: TrackingConsent
    let telemetrySampleRate: Float?

    let site: Datadog.Configuration.DatadogEndpoint?
    let batchSize: Datadog.Configuration.BatchSize?
    let uploadFrequency: Datadog.Configuration.UploadFrequency?
    let firstPartyHosts: [String]
    let customEndpoint: String?
    let additionalConfig: [String: Any]

    let rumConfiguration: RumConfiguration?

    init(
        clientToken: String,
        env: String,
        serviceName: String?,
        trackingConsent: TrackingConsent,
        telemetrySampleRate: Float? = nil,
        nativeCrashReportingEnabled: Bool,
        site: Datadog.Configuration.DatadogEndpoint? = nil,
        batchSize: Datadog.Configuration.BatchSize? = nil,
        uploadFrequency: Datadog.Configuration.UploadFrequency? = nil,
        firstPartyHosts: [String] = [],
        customEndpoint: String? = nil,
        additionalConfig: [String: Any] = [:],
        rumConfiguration: RumConfiguration? = nil
    ) {
        self.clientToken = clientToken
        self.env = env
        self.serviceName = serviceName
        self.trackingConsent = trackingConsent
        self.telemetrySampleRate = telemetrySampleRate
        self.nativeCrashReportingEnabled = nativeCrashReportingEnabled
        self.site = site
        self.batchSize = batchSize
        self.uploadFrequency = uploadFrequency
        self.firstPartyHosts = firstPartyHosts
        self.customEndpoint = customEndpoint
        self.additionalConfig = additionalConfig
        self.rumConfiguration = rumConfiguration
    }

    init?(fromEncoded encoded: [String: Any?]) {
        // Check for required values first
        do {
            clientToken = try castUnwrap(encoded["clientToken"])
            env = try castUnwrap(encoded["env"])
            serviceName = try? castUnwrap(encoded["serviceName"])
            nativeCrashReportingEnabled = try castUnwrap(encoded["nativeCrashReportEnabled"])
            trackingConsent = try TrackingConsent.parseFromFlutter(castUnwrap(encoded["trackingConsent"]))
            telemetrySampleRate = (encoded["telemetrySampleRate"] as? NSNumber)?.floatValue
        } catch {
            return nil
        }

        site = convertOptional(encoded["site"]) {
            .parseFromFlutter($0)
        }
        batchSize = convertOptional(encoded["batchSize"]) {
            .parseFromFlutter($0)
        }
        uploadFrequency = convertOptional(encoded["uploadFrequency"], {
            .parseFromFlutter($0)
        })
        customEndpoint = encoded["customEndpoint"] as? String
        firstPartyHosts = encoded["firstPartyHosts"] as? [String] ?? []
        additionalConfig = encoded["additionalConfig"] as? [String: Any] ?? [:]

        rumConfiguration = convertOptional(encoded["rumConfiguration"]) {
            .init(fromEncoded: $0)
        }
    }

    func toDdConfig() -> Datadog.Configuration {
        let ddConfigBuilder: Datadog.Configuration.Builder
        if let rumConfiguration = rumConfiguration {
            ddConfigBuilder = Datadog.Configuration.builderUsing(rumApplicationID: rumConfiguration.applicationId,
                                                                 clientToken: clientToken,
                                                                 environment: env)
            .set(rumSessionsSamplingRate: rumConfiguration.sampleRate)
        } else {
            ddConfigBuilder = Datadog.Configuration.builderUsing(clientToken: clientToken,
                                                                 environment: env)
        }

        if nativeCrashReportingEnabled {
            _ = ddConfigBuilder.enableCrashReporting(using: DDCrashReportingPlugin())
        }

        if let telemetrySampleRate = telemetrySampleRate {
            _ = ddConfigBuilder.set(sampleTelemetry: telemetrySampleRate)
        }

        if let site = site {
            _ = ddConfigBuilder.set(endpoint: site)
        }
        if let batchSize = batchSize {
            _ = ddConfigBuilder.set(batchSize: batchSize)
        }
        if let uploadFrequency = uploadFrequency {
            _ = ddConfigBuilder.set(uploadFrequency: uploadFrequency)
        }
        if let customEndpoint = customEndpoint {
            if let customEndpointUrl = URL(string: customEndpoint) {
                _ = ddConfigBuilder
                    .set(customLogsEndpoint: customEndpointUrl)
                    .set(customRUMEndpoint: customEndpointUrl)
            }
        }

        _ = ddConfigBuilder.set(additionalConfiguration: additionalConfig)

        if let enableViewTracking = additionalConfig["_dd.native_view_tracking"] as? Bool, enableViewTracking {
            _ = ddConfigBuilder.trackUIKitRUMViews()
        }

        if let serviceName = additionalConfig["_dd.service_name"] as? String {
            _ = ddConfigBuilder.set(serviceName: serviceName)
        }

        if let threshold = additionalConfig["_dd.long_task.threshold"] as? TimeInterval {
            // `_dd.long_task.threshold` attribute is in milliseconds
            _ = ddConfigBuilder.trackRUMLongTasks(threshold: threshold / 1_000)
        }

        return ddConfigBuilder.build()
    }
}

private enum ConfigError: Error {
    case castError
}

func castUnwrap<T>(_ value: Any??) throws -> T {
    guard let testValue = value as? T else {
        throw ConfigError.castError
    }
    return testValue
}

func convertOptional<T, R>(_ value: Any??, _ converter: (T) -> R?) -> R? {
    if let encoded = value as? T {
        return converter(encoded)
    }
    return nil
}

// MARK: - Flutter enum parsing extensions

public extension TrackingConsent {
    static func parseFromFlutter(_ value: String) -> Self {
        switch value {
        case "TrackingConsent.granted": return .granted
        case "TrackingConsent.notGranted": return .notGranted
        case "TrackingConsent.pending": return .pending
        default: return .pending
        }
    }
}

public extension Datadog.Configuration.BatchSize {
    static func parseFromFlutter(_ value: String) -> Self {
        switch value {
        case "BatchSize.small": return .small
        case "BatchSize.medium": return .medium
        case "BatchSize.large": return .large
        default: return .medium
        }
    }
}

public extension Datadog.Configuration.UploadFrequency {
    static func parseFromFlutter(_ value: String) -> Self {
        switch value {
        case "UploadFrequency.frequent": return .frequent
        case "UploadFrequency.average": return .average
        case "UploadFrequency.rare": return .rare
        default: return .average
        }
    }
}

public extension Datadog.Configuration.DatadogEndpoint {
    static func parseFromFlutter(_ value: String) -> Self {
        switch value {
        case "DatadogSite.us1": return .us1
        case "DatadogSite.us3": return .us3
        case "DatadogSite.us5": return .us5
        case "DatadogSite.eu1": return .eu1
        case "DatadogSite.us1Fed": return .us1_fed
        default: return .us1
        }
    }
}

public extension LogLevel {
    static func parseFromFlutter(_ value: String) -> Self? {
        switch value {
        case "Verbosity.verbose": return .debug
        case "Verbosity.debug": return .debug
        case "Verbosity.info": return .info
        case "Verbosity.warn": return .warn
        case "Verbosity.error": return .error
        case "Verbosity.none": return nil
        default: return nil
        }
    }
}
