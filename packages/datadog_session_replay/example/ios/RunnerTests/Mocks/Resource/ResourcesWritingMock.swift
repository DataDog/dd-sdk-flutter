// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation

@testable import datadog_session_replay

class ResourcesWritingMock: ResourcesWriting {
    struct WriteRequest {
        let identifier: String
        let data: Data
        let mimeType: String
    }

    var writeRequests: [WriteRequest] = []

    func write(withIdentifier identifier: String, data: Data, mimeType: String) {
        writeRequests.append(WriteRequest(identifier: identifier, data: data, mimeType: mimeType))
    }

}
