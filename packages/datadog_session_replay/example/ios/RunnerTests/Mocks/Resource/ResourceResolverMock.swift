//// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation

@testable import datadog_session_replay

class ResourceResolverMock: ResourceResolver {
    internal struct TrackedResource {
        let key: Int
        let width: Int
        let height: Int
        let data: Data
        let resourceId: String
    }

    var trackedResources: [TrackedResource] = []

    func addResource(withKey key: Int, width: Int, height: Int, data: Data) {
        trackedResources.append(
            TrackedResource(key: key, width: width, height: height, data: data, resourceId: .mockRandom())
        )
    }

    func resolveResource(withKey: Int) -> String? {
        return trackedResources.first { $0.key == withKey }?.resourceId
    }
}
