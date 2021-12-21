// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import XCTest
import Datadog
import datadog_sdk

// Note: These tests are in the example app because Flutter does not provide a simple
// way to to include tests in the Podspec.
class FlutterSdkTests: XCTestCase {

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
}
