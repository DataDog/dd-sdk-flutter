// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Foundation
import DatadogCore
import DatadogRUM
import DatadogLogs
import DatadogInternal
import DatadogCrashReporting

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
