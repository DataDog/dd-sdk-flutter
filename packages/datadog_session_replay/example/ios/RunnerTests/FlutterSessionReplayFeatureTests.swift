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
    feature.registerSessionReplayContext()

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
    feature.registerSessionReplayContext()
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
    feature.registerSessionReplayContext()
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

@Test
func registersTheSessionReplayContext_WhenNoSessionReplayIsRegistered() throws {
    // Given
    let core = PassthroughCoreMock()
    let feature = try DefaultFlutterSessionReplayFeature(
        core: core,
        configuration: .init(),
        resourceResolver: ResourceResolverMock()
    )

    // When
    feature.registerSessionReplayContext()

    // Then
    let registered = core.feature(named: Feature.sessionReplay, type: SessionReplayContextFeature.self)
    #expect(registered != nil)
}

@Test
func publishesNothing_WhenNativeSessionReplayIsRegistered() throws {
    // Given - a hybrid app configured as standalone
    let core = PassthroughCoreMock()
    try core.register(feature: NativeSessionReplayFeatureMock())
    let feature = try DefaultFlutterSessionReplayFeature(
        core: core,
        configuration: .init(),
        resourceResolver: ResourceResolverMock()
    )

    // When
    feature.registerSessionReplayContext()
    feature.setHasReplay(true)
    feature.setRecordCount(for: "view-id", count: 1)

    // Then - the native Session Replay owns the replay state
    #expect(core.feature(named: Feature.sessionReplay, type: SessionReplayContextFeature.self) == nil)
    #expect(core.context.additionalContext(ofType: SessionReplayCoreContext.HasReplay.self) == nil)
    #expect(core.context.additionalContext(ofType: SessionReplayCoreContext.RecordsCount.self) == nil)
}

private final class NativeSessionReplayFeatureMock: DatadogFeature, SessionReplayConfiguration {
    let messageReceiver: FeatureMessageReceiver = NOPFeatureMessageReceiver()
    let textAndInputPrivacyLevel: TextAndInputPrivacyLevel = .maskAll
    let imagePrivacyLevel: ImagePrivacyLevel = .maskAll
    let touchPrivacyLevel: TouchPrivacyLevel = .hide
}
