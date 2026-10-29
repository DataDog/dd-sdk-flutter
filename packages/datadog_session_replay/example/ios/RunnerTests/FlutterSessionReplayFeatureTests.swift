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
func sessionReplayContext_SharesFlutterPrivacyLevels_WithWebViewTracking() throws {
    // Given
    let core = PassthroughCoreMock()
    let feature = try DefaultFlutterSessionReplayFeature(
        core: core,
        configuration: .init(
            textAndInputPrivacyLevel: .maskSensitiveInputs,
            imagePrivacyLevel: .maskNone,
            touchPrivacyLevel: .show
        ),
        resourceResolver: ResourceResolverMock()
    )

    // When
    feature.registerSessionReplayContext()

    // Then - `WebViewTracking` looks Session Replay up by this name and type
    let registered = try #require(core.feature(named: Feature.sessionReplay, type: SessionReplayConfiguration.self))
    #expect(registered.textAndInputPrivacyLevel == .maskSensitiveInputs)
    #expect(registered.imagePrivacyLevel == .maskNone)
    #expect(registered.touchPrivacyLevel == .show)
    #expect(!core.isNativeSessionReplayRegistered)
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

// MARK: - WebView Session Replay

private func mockWebView(id: String) throws -> WebViewMessage.View {
    try JSONDecoder().decode(WebViewMessage.View.self, from: Data(#"{"id":"\#(id)"}"#.utf8))
}

private func sampling(selecting sessionID: String?) -> ReplaySampling {
    let sampling = ReplaySampling()
    if let sessionID {
        sampling.setSessionSampled(for: sessionID, sampled: true)
    }
    return sampling
}

private struct NativeSessionReplayFeatureMock: DatadogFeature, SessionReplayConfiguration {
    static let name = "session-replay"
    let messageReceiver: FeatureMessageReceiver = NOPFeatureMessageReceiver()
    let textAndInputPrivacyLevel: TextAndInputPrivacyLevel = .maskAll
    let imagePrivacyLevel: ImagePrivacyLevel = .maskAll
    let touchPrivacyLevel: TouchPrivacyLevel = .hide
}

@Test
func exposesPrivacyLevels_AsSessionReplayConfiguration() throws {
    // Given
    let core = PassthroughCoreMock()
    let config = DefaultFlutterSessionReplayFeature.Configuration(
        textAndInputPrivacyLevel: .maskSensitiveInputs,
        imagePrivacyLevel: .maskNone,
        touchPrivacyLevel: .show
    )

    // When
    let feature: SessionReplayConfiguration = try DefaultFlutterSessionReplayFeature(
        core: core,
        configuration: config,
        resourceResolver: ResourceResolverMock()
    )

    // Then
    #expect(DefaultFlutterSessionReplayFeature.name == "flutter-session-replay")
    #expect(feature.textAndInputPrivacyLevel == .maskSensitiveInputs)
    #expect(feature.imagePrivacyLevel == .maskNone)
    #expect(feature.touchPrivacyLevel == .show)
}

@Test
func defaultsToMostRestrictivePrivacyLevels() throws {
    let config = DefaultFlutterSessionReplayFeature.Configuration()

    #expect(config.textAndInputPrivacyLevel == .maskAll)
    #expect(config.imagePrivacyLevel == .maskAll)
    #expect(config.touchPrivacyLevel == .hide)
}

@Test
func webViewRecordReceiver_WritesRecord_WhenRUMSessionIsSampled() throws {
    // Given
    let rumContext = RUMCoreContext.mockRandom()
    var context: DatadogContext = .mockRandom()
    context.set(additionalContext: rumContext)
    context.set(additionalContext: RUMWebViewContext(serverTimeOffsets: ["web-view": 1.5]))
    let core = PassthroughCoreMock(context: context)
    let receiver = WebViewRecordReceiver(scope: core, replaySampling: sampling(selecting: rumContext.sessionID))

    // When
    let handled = receiver.receive(
        message: .webview(.record(["type": 2, "timestamp": 1_000], try mockWebView(id: "web-view"))),
        from: core
    )

    // Then
    #expect(handled)
    let records = core.events(ofType: WebViewRecordReceiver.WebRecord.self)
    try #require(records.count == 1)
    #expect(records[0].applicationID == rumContext.applicationID)
    #expect(records[0].sessionID == rumContext.sessionID)
    #expect(records[0].viewID == "web-view")

    // Written records must decode the way `RequestBuilder` reads them, with the server time offset applied
    let data = try JSONEncoder().encode(records[0])
    let enriched = try EnrichedRecordJSON(jsonObjectData: data)
    #expect(enriched.records.first?["timestamp"] as? Int64 == 2_500)
}

@Test
func webViewRecordReceiver_DropsRecord_WhenRUMSessionIsNotSampled() throws {
    // Given
    var context: DatadogContext = .mockRandom()
    let rumContext = RUMCoreContext.mockWith(sessionSampler: .mockRejectAll())
    context.set(additionalContext: rumContext)
    let core = PassthroughCoreMock(context: context)
    let receiver = WebViewRecordReceiver(scope: core, replaySampling: sampling(selecting: rumContext.sessionID))

    // When
    _ = receiver.receive(message: .webview(.record(["type": 2], try mockWebView(id: "web-view"))), from: core)

    // Then
    #expect(core.events.isEmpty)
}

@Test
func webViewRecordReceiver_DropsRecord_WhenReplaySampleRateDidNotSelectTheSession() throws {
    // Given
    let rumContext = RUMCoreContext.mockRandom()
    var context: DatadogContext = .mockRandom()
    context.set(additionalContext: rumContext)
    let core = PassthroughCoreMock(context: context)
    let replaySampling = ReplaySampling()
    replaySampling.setSessionSampled(for: rumContext.sessionID, sampled: false)
    let receiver = WebViewRecordReceiver(scope: core, replaySampling: replaySampling)

    // When
    _ = receiver.receive(message: .webview(.record(["type": 2], try mockWebView(id: "web-view"))), from: core)

    // Then
    #expect(core.events.isEmpty)
}

@Test(arguments: [nil, "previous-session"] as [String?])
func webViewRecordReceiver_DropsRecord_WhenTheSessionWasNotReportedSampled(sampledSessionID: String?) throws {
    // Given - no decision yet, or one for an earlier session
    var context: DatadogContext = .mockRandom()
    context.set(additionalContext: RUMCoreContext.mockRandom())
    let core = PassthroughCoreMock(context: context)
    let receiver = WebViewRecordReceiver(scope: core, replaySampling: sampling(selecting: sampledSessionID))

    // When
    _ = receiver.receive(message: .webview(.record(["type": 2], try mockWebView(id: "web-view"))), from: core)

    // Then
    #expect(core.events.isEmpty)
}

@Test
func webViewRecordReceiver_WritesRecord_WhileFlutterRecordingIsStopped() throws {
    // Given - a sampled session, with recording not started (`has_replay` false). The Browser SDK
    // sends its full snapshot when the page loads, so it must be kept for when recording starts.
    let rumContext = RUMCoreContext.mockRandom()
    var context: DatadogContext = .mockRandom()
    context.set(additionalContext: rumContext)
    context.set(additionalContext: SessionReplayCoreContext.HasReplay(value: false))
    let core = PassthroughCoreMock(context: context)
    let receiver = WebViewRecordReceiver(scope: core, replaySampling: sampling(selecting: rumContext.sessionID))

    // When
    _ = receiver.receive(message: .webview(.record(["type": 2], try mockWebView(id: "web-view"))), from: core)

    // Then
    #expect(core.events(ofType: WebViewRecordReceiver.WebRecord.self).count == 1)
}

@Test
func webViewRecordReceiver_IgnoresRecord_WhenNativeSessionReplayIsEnabled() throws {
    // Given
    var context: DatadogContext = .mockRandom()
    context.set(additionalContext: RUMCoreContext.mockRandom())
    let core = PassthroughCoreMock(context: context)
    try core.register(feature: NativeSessionReplayFeatureMock())
    let receiver = WebViewRecordReceiver(scope: core, replaySampling: sampling(selecting: nil))

    // When
    let handled = receiver.receive(
        message: .webview(.record(["type": 2], try mockWebView(id: "web-view"))),
        from: core
    )

    // Then
    #expect(!handled)
    #expect(core.events.isEmpty)
}

@Test
func webViewRecordReceiver_WritesRecord_WhenSessionReplayContextIsRegistered() throws {
    // Given - Flutter Session Replay standing in for the native one
    let rumContext = RUMCoreContext.mockRandom()
    var context: DatadogContext = .mockRandom()
    context.set(additionalContext: rumContext)
    let core = PassthroughCoreMock(context: context)
    try core.register(feature: SessionReplayContextFeature(configuration: NativeSessionReplayFeatureMock()))
    let receiver = WebViewRecordReceiver(scope: core, replaySampling: sampling(selecting: rumContext.sessionID))

    // When
    let handled = receiver.receive(
        message: .webview(.record(["type": 2], try mockWebView(id: "web-view"))),
        from: core
    )

    // Then
    #expect(handled)
    #expect(core.events(ofType: WebViewRecordReceiver.WebRecord.self).count == 1)
}

@Test
func webViewRecordReceiver_IgnoresOtherMessages() throws {
    let core = PassthroughCoreMock()
    let receiver = WebViewRecordReceiver(scope: core, replaySampling: sampling(selecting: nil))

    #expect(!receiver.receive(message: .webview(.rum(["type": "view"])), from: core))
    #expect(core.events.isEmpty)
}
