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
        let detectLongTasks: Bool
        let longTaskThreshold: Float
        let customEndpoint: String?
        let vitalsFrequency: Datadog.Configuration.VitalsFrequency?
        let attachViewEventMapper: Bool
        let attachActionEventMapper: Bool
        let attachResourceEventMapper: Bool
        let attachErrorEventMapper: Bool

        init(applicationId: String,
             sampleRate: Float,
             detectLongTasks: Bool,
             longTaskThreshold: Float,
             customEndpoint: String?,
             vitalsFrequency: Datadog.Configuration.VitalsFrequency?,
             attachViewEventMapper: Bool,
             attachActionEventMapper: Bool,
             attachResourceEventMapper: Bool,
             attachErrorEventMapper: Bool
        ) {
            self.applicationId = applicationId
            self.sampleRate = sampleRate
            self.detectLongTasks = detectLongTasks
            self.longTaskThreshold = longTaskThreshold
            self.customEndpoint = customEndpoint
            self.vitalsFrequency = vitalsFrequency
            self.attachViewEventMapper = attachViewEventMapper
            self.attachActionEventMapper = attachActionEventMapper
            self.attachResourceEventMapper = attachResourceEventMapper
            self.attachErrorEventMapper = attachErrorEventMapper
        }

        init?(fromEncoded encoded: [String: Any?]) {
            do {
                applicationId = try castUnwrap(encoded["applicationId"])
            } catch {
                return nil
            }

            sampleRate = (encoded["sampleRate"] as? NSNumber)?.floatValue ?? 100.0
            detectLongTasks = (encoded["detectLongTasks"] as? NSNumber)?.boolValue ?? true
            longTaskThreshold = (encoded["longTaskThreshold"] as? NSNumber)?.floatValue ?? 0.1
            customEndpoint = encoded["customEndpoint"] as? String
            attachViewEventMapper = (encoded["attachViewEventMapper"] as? NSNumber)?.boolValue ?? false
            attachActionEventMapper = (encoded["attachActionEventMapper"] as? NSNumber)?.boolValue ?? false
            attachResourceEventMapper = (encoded["attachResourceEventMapper"] as? NSNumber)?.boolValue ?? false
            attachErrorEventMapper = (encoded["attachErrorEventMapper"] as? NSNumber)?.boolValue ?? false

            vitalsFrequency = convertOptional(encoded["vitalsFrequency"]) {
                .parseFromFlutter($0)
            }
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
    let customLogsEndpoint: String?
    let additionalConfig: [String: Any]
    let attachLogMapper: Bool

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
        customLogsEndpoint: String? = nil,
        additionalConfig: [String: Any] = [:],
        attachLogMapper: Bool = false,
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
        self.customLogsEndpoint = customLogsEndpoint
        self.additionalConfig = additionalConfig
        self.attachLogMapper = attachLogMapper
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
        customLogsEndpoint = encoded["customLogsEndpoint"] as? String
        firstPartyHosts = encoded["firstPartyHosts"] as? [String] ?? []
        additionalConfig = encoded["additionalConfig"] as? [String: Any] ?? [:]
        attachLogMapper = (encoded["attachLogMapper"] as? NSNumber)?.boolValue ?? false

        rumConfiguration = convertOptional(encoded["rumConfiguration"]) {
            .init(fromEncoded: $0)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func toDdConfigBuilder() -> Datadog.Configuration.Builder {
        let ddConfigBuilder: Datadog.Configuration.Builder
        if let rumConfig = rumConfiguration {
            ddConfigBuilder = Datadog.Configuration.builderUsing(
                rumApplicationID: rumConfig.applicationId,
                clientToken: clientToken,
                environment: env
            )
            .enableTracing(false)
            .set(rumSessionsSamplingRate: rumConfig.sampleRate)

            if rumConfig.detectLongTasks {
                _ = ddConfigBuilder.trackRUMLongTasks(threshold: TimeInterval(rumConfig.longTaskThreshold))
            }
            if let customRumEndpoint = rumConfig.customEndpoint,
               let customRumEndpointUrl = URL(string: customRumEndpoint) {
                _ = ddConfigBuilder.set(customRUMEndpoint: customRumEndpointUrl)
            }
            if let vitalsFrequency = rumConfig.vitalsFrequency {
                _ = ddConfigBuilder.set(mobileVitalsFrequency: vitalsFrequency)
            }
        } else {
            ddConfigBuilder = Datadog.Configuration.builderUsing(
                clientToken: clientToken,
                environment: env
            )
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

        if !firstPartyHosts.isEmpty {
            _ = ddConfigBuilder.trackURLSession(firstPartyHosts: Set(firstPartyHosts))
        }

        if let customEndpoint = customLogsEndpoint,
           let customEndpointUrl = URL(string: customEndpoint) {
            _ = ddConfigBuilder
                .set(customLogsEndpoint: customEndpointUrl)
        }

        if let enableViewTracking = additionalConfig["_dd.native_view_tracking"] as? Bool,
           enableViewTracking {
            _ = ddConfigBuilder.trackUIKitRUMViews()
        }

        if let serviceName = serviceName {
            _ = ddConfigBuilder.set(serviceName: serviceName)
        }

        _ = ddConfigBuilder.set(additionalConfiguration: additionalConfig)

        return ddConfigBuilder
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
    static func parseVerbosityFromFlutter(_ value: String) -> Self? {
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

    static func parseLogLevelFromFlutter(_ value: String) -> Self {
        switch value {
        case "LogLevel.debug": return .debug
        case "LogLevel.info": return .info
        case "LogLevel.notice": return .notice
        case "LogLevel.warning": return .warn
        case "LogLevel.error": return .error
        case "LogLevel.critical": return .critical
        case "LogLevel.alert": return .critical
        case "LogLevel.emergency": return .critical
        default: return .info
        }
    }
}
