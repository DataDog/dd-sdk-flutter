// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation
import DatadogInternal
import CryptoKit
import UIKit
import CoreGraphics

public protocol ResourceResolver {
    func addResource(withKey key: Int, width: Int, height: Int, data: Data)
    func resolveResource(withKey: Int) -> String?
}

internal class DefaultResourceResolver: ResourceResolver {
    private class ResourceEntry {
        let resourceKey: Int
        let width: Int
        let height: Int
        var resourceId: String?
        var resourceBytes: Data?

        init(resourceKey: Int, width: Int, height: Int, resourceBytes: Data? = nil) {
            self.resourceKey = resourceKey
            self.width = width
            self.height = height
            self.resourceBytes = resourceBytes
        }
    }

    private let resourcesWriter: ResourcesWriting
    private var resourceEntries: [Int: ResourceEntry] = [:]
    private var processedIdentifiers = Set<String>()

    init(writer: ResourcesWriting) {
        resourcesWriter = writer
    }

    func addResource(withKey key: Int, width: Int, height: Int, data: Data) {
        if resourceEntries[key] == nil {
            resourceEntries[key] = ResourceEntry(resourceKey: key, width: width, height: height, resourceBytes: data)
        }
    }

    func resolveResource(withKey: Int) -> String? {
        guard let resourceEntry = resourceEntries[withKey] else {
            return nil
        }

        if let resourceId = resourceEntry.resourceId {
            return resourceId
        }

        guard var resourceBytes = resourceEntry.resourceBytes else {
            return nil
        }

        // Immediately discard retaining these bytes, regardless of png and hashing outcome
        resourceEntry.resourceBytes = nil
        return resourceBytes.withUnsafeMutableBytes { (dataPointer: UnsafeMutableRawBufferPointer) in
            let cgContext = CGContext(data: dataPointer.baseAddress,
                                      width: resourceEntry.width,
                                      height: resourceEntry.height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 4 * resourceEntry.width,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            guard let cgImage = cgContext?.makeImage() else {
                return nil
            }

            let image = UIImage(cgImage: cgImage)

            guard let pngData = image.pngData() else {
                return nil
            }

            let digest = Insecure.MD5.hash(data: pngData)
            let md5String = digest.map { String(format: "%02hhx", $0) }.joined()
            resourceEntry.resourceId = md5String

            resourcesWriter.write(withIdentifier: md5String, data: pngData, mimeType: "image/png")

            return md5String
        }
    }
}
