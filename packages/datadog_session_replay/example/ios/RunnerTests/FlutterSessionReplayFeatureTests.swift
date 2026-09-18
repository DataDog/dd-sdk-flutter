// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation
import Testing
import DatadogInternal

@testable import datadog_session_replay

@Test
func setsReplayBaggage_WhenSetHasReplay() throws {
    // Given
    let core = PassthroughCoreMock()
    let config = DefaultFlutterSessionReplayFeature.Configuration()
    let feature = try DefaultFlutterSessionReplayFeature(
        core: core,
        configuration: config,
        resourceResolver: ResourceResolverMock()
    )

    // When
    let expectedValue: Bool = .mockRandom()
    feature.setHasReplay(expectedValue)

    // Then
    let value = core.context.additionalContext(ofType: SessionReplayCoreContext.HasReplay.self)
    #expect(value?.value == expectedValue)
}

@Test
func setsBaggage_WhenSetRecordCount() throws {
    // Given
    let core = PassthroughCoreMock()
    let config = DefaultFlutterSessionReplayFeature.Configuration()
    let feature = try DefaultFlutterSessionReplayFeature(
        core: core,
        configuration: config,
        resourceResolver: ResourceResolverMock()
    )
    // When
    let viewId: String = .mockRandom()
    let expectedCount: Int64 = .mockRandom()
    feature.setRecordCount(for: viewId, count: expectedCount)

    // Then
    let baggage = core.context.additionalContext(ofType: SessionReplayCoreContext.RecordsCount.self)
    let value = baggage?.value[viewId] as? Int64
    #expect(value == expectedCount)
}

@Test
func setsBaggage_WhenSetRecordCount_MultipleViews() throws {
    // Given
    let core = PassthroughCoreMock()
    let config = DefaultFlutterSessionReplayFeature.Configuration()
    let feature = try DefaultFlutterSessionReplayFeature(
        core: core,
        configuration: config,
        resourceResolver: ResourceResolverMock()
    )
    // When
    let viewIdA: String = .mockRandom()
    let viewIdB: String = .mockRandom()
    let expectedCountA: Int64 = .mockRandom()
    let expectedCountB: Int64 = .mockRandom()
    feature.setRecordCount(for: viewIdA, count: expectedCountA)
    feature.setRecordCount(for: viewIdB, count: expectedCountB)

    // Then
    let baggage = core.context.additionalContext(ofType: SessionReplayCoreContext.RecordsCount.self)
    let valueA = baggage?.value[viewIdA] as? Int64
    #expect(valueA == expectedCountA)
    let valueB = baggage?.value[viewIdB] as? Int64
    #expect(valueB == expectedCountB)
}
