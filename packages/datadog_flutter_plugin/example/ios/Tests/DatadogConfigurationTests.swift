// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Foundation
import XCTest
@testable import Datadog
@testable import datadog_flutter_plugin

class DatadogConfigurationTests: XCTestCase {

  func testAllBatchSizes_AreParsedCorrectly() {
    let small = Datadog.Configuration.BatchSize.parseFromFlutter("BatchSize.small")
    let medium = Datadog.Configuration.BatchSize.parseFromFlutter("BatchSize.medium")
    let large = Datadog.Configuration.BatchSize.parseFromFlutter("BatchSize.large")

    XCTAssertEqual(small, .small)
    XCTAssertEqual(medium, .medium)
    XCTAssertEqual(large, .large)
  }

  func testAllUploadFrequency_AreParsedCorrectly() {
    let frequent = Datadog.Configuration.UploadFrequency.parseFromFlutter("UploadFrequency.frequent")
    let average = Datadog.Configuration.UploadFrequency.parseFromFlutter("UploadFrequency.average")
    let rare = Datadog.Configuration.UploadFrequency.parseFromFlutter("UploadFrequency.rare")

    XCTAssertEqual(frequent, .frequent)
    XCTAssertEqual(average, .average)
    XCTAssertEqual(rare, .rare)
  }

  func testAllTrackingConsents_AreParsedCorrectly() {
    let granted = TrackingConsent.parseFromFlutter("TrackingConsent.granted")
    let notGranted = TrackingConsent.parseFromFlutter("TrackingConsent.notGranted")
    let pending = TrackingConsent.parseFromFlutter("TrackingConsent.pending")

    XCTAssertEqual(granted, .granted)
    XCTAssertEqual(notGranted, .notGranted)
    XCTAssertEqual(pending, .pending)
  }

  func testAllSites_AreParsedCorrectly() {
    let us1 = Datadog.Configuration.DatadogEndpoint.parseFromFlutter("DatadogSite.us1")
    let us3 = Datadog.Configuration.DatadogEndpoint.parseFromFlutter("DatadogSite.us3")
    let us5 = Datadog.Configuration.DatadogEndpoint.parseFromFlutter("DatadogSite.us5")
    let eu1 = Datadog.Configuration.DatadogEndpoint.parseFromFlutter("DatadogSite.eu1")
    let us1Fed = Datadog.Configuration.DatadogEndpoint.parseFromFlutter("DatadogSite.us1Fed")

    XCTAssertEqual(us1, .us1)
    XCTAssertEqual(us3, .us3)
    XCTAssertEqual(us5, .us5)
    XCTAssertEqual(eu1, .eu1)
    XCTAssertEqual(us1Fed, .us1_fed)
  }

  func testAllVerbosityLevels_AreParsedCorrectly() {
    let verbose = LogLevel.parseFromFlutter("Verbosity.verbose")
    let debug = LogLevel.parseFromFlutter("Verbosity.debug")
    let info = LogLevel.parseFromFlutter("Verbosity.info")
    let warn = LogLevel.parseFromFlutter("Verbosity.warn")
    let error = LogLevel.parseFromFlutter("Verbosity.error")
    let none = LogLevel.parseFromFlutter("Verbosity.none")
    let unknown = LogLevel.parseFromFlutter("unknown")

    // iOS doesn't have .verbose so use .debug
    XCTAssertEqual(verbose, .debug)
    XCTAssertEqual(debug, .debug)
    XCTAssertEqual(info, .info)
    XCTAssertEqual(warn, .warn)
    XCTAssertEqual(error, .error)
    XCTAssertNil(none)
    XCTAssertNil(unknown)
  }

  func testConfiguration_MissingValues_FailsInitialization() {
    let encoded: [String: Any?]  = [
      "env": "fakeEnvironment",
      "nativeCrashReportEnabled": NSNumber(false),
      "trackingConsent": "TrackingConsent.pending",
      "additionalConfig": [:]
    ]

    let config = DatadogFlutterConfiguration(fromEncoded: encoded)
    XCTAssertNil(config)
  }

  func testConfiguration_Defaults_AreDecoded() {
    let encoded: [String: Any?]  = [
      "clientToken": "fakeClientToken",
      "env": "fakeEnvironment",
      "nativeCrashReportEnabled": NSNumber(false),
      "site": nil,
      "batchSize": nil,
      "uploadFrequency": nil,
      "telemetrySampleRate": nil,
      "trackingConsent": "TrackingConsent.pending",
      "customEndpoint": nil,
      "firstPartyHosts": [],
      "loggingConfiguration": nil,
      "rumConfiguration": nil,
      "additionalConfig": [:]
    ]

    let config = DatadogFlutterConfiguration(fromEncoded: encoded)!

    XCTAssertNotNil(config)
    XCTAssertEqual(config.clientToken, "fakeClientToken")
    XCTAssertEqual(config.env, "fakeEnvironment")
    XCTAssertEqual(config.nativeCrashReportingEnabled, false)
    XCTAssertNil(config.telemetrySampleRate)
    XCTAssertEqual(config.trackingConsent, TrackingConsent.pending)

    XCTAssertNil(config.rumConfiguration)
  }

  func testConfiguration_Values_AreDecoded() {
    let encoded: [String: Any?]  = [
      "clientToken": "fakeClientToken",
      "env": "fakeEnvironment",
      "nativeCrashReportEnabled": NSNumber(false),
      "site": "DatadogSite.eu1",
      "batchSize": "BatchSize.small",
      "uploadFrequency": "UploadFrequency.frequent",
      "trackingConsent": "TrackingConsent.pending",
      "telemetrySampleRate": 44,
      "customEndpoint": nil,
      "firstPartyHosts": [ "first_party.com" ],
      "loggingConfiguration": nil,
      "rumConfiguration": nil,
      "additionalConfig": [:]
    ]

    let config = DatadogFlutterConfiguration(fromEncoded: encoded)!

    XCTAssertNotNil(config)
    XCTAssertEqual(config.site, .eu1)
    XCTAssertNil(config.serviceName)
    XCTAssertEqual(config.batchSize, .small)
    XCTAssertEqual(config.uploadFrequency, .frequent)
    XCTAssertEqual(config.firstPartyHosts, ["first_party.com"])
    XCTAssertEqual(config.trackingConsent, TrackingConsent.pending)
    XCTAssertEqual(config.telemetrySampleRate, 44)

    XCTAssertNil(config.rumConfiguration)
  }

    func testConfiguration_ServiceName_IsDecoded() {
      let encoded: [String: Any?]  = [
        "clientToken": "fakeClientToken",
        "env": "fakeEnvironment",
        "serviceName": "com.servicename",
        "nativeCrashReportEnabled": NSNumber(false),
        "site": "DatadogSite.eu1",
        "batchSize": "BatchSize.small",
        "uploadFrequency": "UploadFrequency.frequent",
        "trackingConsent": "TrackingConsent.pending",
        "customEndpoint": nil,
        "firstPartyHosts": [ "first_party.com" ],
        "loggingConfiguration": nil,
        "rumConfiguration": nil,
        "additionalConfig": [:]
      ]

      let config = DatadogFlutterConfiguration(fromEncoded: encoded)!

      XCTAssertNotNil(config)
      XCTAssertEqual(config.serviceName, "com.servicename")
    }

  func testConfiguration_NestedConfigurations_AreDecoded() {
    let encoded: [String: Any?]  = [
      "clientToken": "fakeClientToken",
      "env": "fakeEnvironment",
      "nativeCrashReportEnabled": NSNumber(false),
      "site": nil,
      "batchSize": nil,
      "uploadFrequency": nil,
      "trackingConsent": "TrackingConsent.pending",
      "customEndpoint": nil,
      "loggingConfiguration": [
        "sendNetworkInfo": NSNumber(true),
        "printLogsToConsole": NSNumber(true)
      ],
      "rumConfiguration": [
        "applicationId": "fakeApplicationId"
      ],
      "additionalConfig": [:]
    ]

    let config = DatadogFlutterConfiguration(fromEncoded: encoded)!

    XCTAssertNotNil(config.rumConfiguration)
    XCTAssertEqual(config.rumConfiguration?.applicationId, "fakeApplicationId")
  }
}
