// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Foundation
import XCTest
@testable import DatadogCore
@testable import DatadogInternal
@testable import DatadogLogs
@testable import DatadogRUM
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
        let us1 = DatadogSite.parseFromFlutter("DatadogSite.us1")
        let us3 = DatadogSite.parseFromFlutter("DatadogSite.us3")
        let us5 = DatadogSite.parseFromFlutter("DatadogSite.us5")
        let eu1 = DatadogSite.parseFromFlutter("DatadogSite.eu1")
        let us1Fed = DatadogSite.parseFromFlutter("DatadogSite.us1Fed")
        let ap1 = DatadogSite.parseFromFlutter("DatadogSite.ap1")

        XCTAssertEqual(us1, .us1)
        XCTAssertEqual(us3, .us3)
        XCTAssertEqual(us5, .us5)
        XCTAssertEqual(eu1, .eu1)
        XCTAssertEqual(us1Fed, .us1_fed)
        XCTAssertEqual(ap1, .ap1)
    }

    func testAllVitalsFrequencies_AreParsedCorrectly() {
        let rare = RUM.Configuration.VitalsFrequency.parseFromFlutter("VitalsFrequency.rare")
        let average = RUM.Configuration.VitalsFrequency.parseFromFlutter("VitalsFrequency.average")
        let frequent = RUM.Configuration.VitalsFrequency.parseFromFlutter("VitalsFrequency.frequent")

        XCTAssertEqual(rare, .rare)
        XCTAssertEqual(average, .average)
        XCTAssertEqual(frequent, .frequent)
    }

    func testCoreConfiguration_MissingValues_FailsInitialization() {
        let encoded: [String: Any?]  = [
            "env": "fakeEnvironment",
            "trackingConsent": "TrackingConsent.pending",
            "additionalConfig": [:] as [String: Any?]
        ]

        let config = Datadog.Configuration(fromEncoded: encoded)
        XCTAssertNil(config)
    }

    func testCoreConfiguration_Defaults_AreDecoded() {
        let encoded: [String: Any?]  = [
            "clientToken": "fakeClientToken",
            "env": "fakeEnvironment",
            "site": nil,
            "batchSize": nil,
            "uploadFrequency": nil,
            "additionalConfig": [:] as [String: Any?]
        ]

        let config = Datadog.Configuration(fromEncoded: encoded)!

        XCTAssertNotNil(config)
        XCTAssertEqual(config.clientToken, "fakeClientToken")
        XCTAssertEqual(config.env, "fakeEnvironment")
        XCTAssertEqual(config.site, .us1)
        XCTAssertEqual(config.batchSize, .medium)
        XCTAssertEqual(config.uploadFrequency, .average)

    }

    func testCoreConfiguration_Values_AreDecoded() {
        let encoded: [String: Any?]  = [
            "clientToken": "fakeClientToken",
            "env": "fakeEnvironment",
            "site": "DatadogSite.eu1",
            "batchSize": "BatchSize.small",
            "uploadFrequency": "UploadFrequency.frequent",
            "trackingConsent": "TrackingConsent.pending",
            "additionalConfig": [:] as [String: Any?]
        ]

        let config = Datadog.Configuration(fromEncoded: encoded)!

        XCTAssertNotNil(config)
        XCTAssertEqual(config.site, .eu1)
        XCTAssertNil(config.service)
        XCTAssertEqual(config.batchSize, .small)
        XCTAssertEqual(config.uploadFrequency, .frequent)
    }

    func testCoreConfiguration_ServiceName_IsDecoded() {
        let encoded: [String: Any?]  = [
            "clientToken": "fakeClientToken",
            "env": "fakeEnvironment",
            "service": "com.servicename",
            "site": "DatadogSite.eu1",
            "batchSize": "BatchSize.small",
            "uploadFrequency": "UploadFrequency.frequent",
            "additionalConfig": [:] as [String: Any?]
        ]

        let config = Datadog.Configuration(fromEncoded: encoded)!

        XCTAssertNotNil(config)
        XCTAssertEqual(config.service, "com.servicename")
    }
}
