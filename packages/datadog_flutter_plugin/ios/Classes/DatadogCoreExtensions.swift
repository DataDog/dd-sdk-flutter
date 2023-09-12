// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import Foundation
import DatadogCore
import DatadogInternal

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

public extension DatadogSite {
    static func parseFromFlutter(_ value: String) -> Self {
        switch value {
        case "DatadogSite.us1": return .us1
        case "DatadogSite.us3": return .us3
        case "DatadogSite.us5": return .us5
        case "DatadogSite.eu1": return .eu1
        case "DatadogSite.us1Fed": return .us1_fed
        case "DatadogSite.ap1": return .ap1
        default: return .us1
        }
    }
}

extension CoreLoggerLevel {
    static func parseFromFlutter(_ value: String) -> Self {
        switch value {
        case "DatadogCoreLoggerLevel.debug": return .debug
        case "DatadogCoreLoggerLevel.warn": return .warn
        case "DatadogCoreLoggerLevel.error": return .error
        case "DatadogCoreLoggerLevel.critical": return .critical
        default: return .debug
        }
    }
}
