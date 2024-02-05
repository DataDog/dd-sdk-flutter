// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Foundation
import Flutter
import XCTest
import DatadogCore

@testable import datadog_flutter_plugin

class FlutterSdkAttributesTests: XCTestCase {
    func testAttributes_SimpleValues_AreEncodedProperly() {
        let flutterTypes: [String: Any?] = [
            "intValue": NSNumber(value: 8),
            "doubleValue": NSNumber(value: 3.1415),
            "booleanValue": NSNumber(value: false),
            "stringValue": "String value",
            "nullValue": nil
        ]
        let encoded = castFlutterAttributesToSwift(flutterTypes)

        XCTAssertEqual(encoded["intValue"] as? Int64, 8)
        XCTAssertEqual(encoded["doubleValue"] as? Double, 3.1415)
        XCTAssertEqual(encoded["booleanValue"] as? Bool, false)
        XCTAssertEqual(encoded["stringValue"] as? String, "String value")
    }

    func testAttributes_NestedTypes_AreEncodedProperly() {
        let flutterTypes: [String: Any?] = [
            "arrayType": [ "My String Value", NSNumber(value: 32) ] as [Any],
            "objectType": [
                "doubleValue": NSNumber(value: 3.1415),
                "booleanValue": NSNumber(value: true)
            ]
        ]
        let encoded = castFlutterAttributesToSwift(flutterTypes)

        // One level deep, values aren't encoded
        let array = (encoded["arrayType"] as? DdFlutterEncodable)?.value as? [Any]
        XCTAssertNotNil(array)
        XCTAssertEqual(array?[0] as? String, "My String Value")
        XCTAssertEqual(array?[1] as? Int64, 32)

        let object = (encoded["objectType"] as? DdFlutterEncodable)?.value as? [String: Any?]
        XCTAssertNotNil(object)
        XCTAssertEqual(object?["doubleValue"] as? Double, 3.1415)
        XCTAssertEqual(object?["booleanValue"] as? Bool, true)
    }

    // Testing all FlutterStandardTypedData types
    func uint8FlutterTypedData() -> FlutterStandardTypedData {
        var array: [UInt8] = [1, 3]
        let data = Data(bytes: &array, count: array.count * MemoryLayout<UInt8>.stride)

        return FlutterStandardTypedData(bytes: data)
    }

    func int32FlutterTypedData() -> FlutterStandardTypedData {
        var array: [Int32] = [-1, 1442]
        let data = Data(bytes: &array, count: array.count * MemoryLayout<Int32>.stride)

        return FlutterStandardTypedData(int32: data)
    }

    func int64FlutterTypedData() -> FlutterStandardTypedData {
        var array: [Int64] = [-1, 9999991234]
        let data = Data(bytes: &array, count: array.count * MemoryLayout<Int64>.stride)

        return FlutterStandardTypedData(int64: data)
    }

    func doubleFlutterTypedData() -> FlutterStandardTypedData {
        var array: [Double] = [2.3, 3.5]
        let data = Data(bytes: &array, count: array.count * MemoryLayout<Double>.stride)

        return FlutterStandardTypedData(float64: data)
    }

    func floatFlutterTypedData() -> FlutterStandardTypedData {
        var floatData: [Float] = [1.0, 3.3]
        let data = Data(bytes: &floatData, count: floatData.count * MemoryLayout<Float>.stride)

        return FlutterStandardTypedData(float32: data)
    }

    func testAttributes_FlutterStandardTypedData_IsEncodedProperly() throws {
        let flutterTypes: [String: Any?] = [
            "uint8": uint8FlutterTypedData(),
            "int32": int32FlutterTypedData(),
            "int64": int64FlutterTypedData(),
            "float": floatFlutterTypedData(),
            "double": doubleFlutterTypedData()
        ]

        let cast = castFlutterAttributesToSwift(flutterTypes)
        let encoded = try JSONEncoder().encode(cast)
        let decoded = try JSONSerialization.jsonObject(with: encoded) as? [String: Any?]

        XCTAssertEqual(decoded?["uint8"] as? [Int], [1, 3])
        XCTAssertEqual(decoded?["int32"] as? [Int], [-1, 1442])
        XCTAssertEqual(decoded?["int64"] as? [Int64], [-1, 9999991234])
        // This is flakey depending on XCode version.
        //XCTAssertEqual(decoded?["float"] as? [Double], [1.0, 3.3])
        XCTAssertEqual(decoded?["double"] as? [Double], [2.3, 3.5])
    }
}

extension JSONEncoder {
    private struct EncodableWrapper: Encodable {
        let wrapped: Encodable

        func encode(to encoder: Encoder) throws {
            try self.wrapped.encode(to: encoder)
        }
    }
    func encode<Key: Encodable>(_ dictionary: [Key: Encodable]) throws -> Data {
        let wrappedDict = dictionary.mapValues(EncodableWrapper.init(wrapped:))
        return try self.encode(wrappedDict)
    }
}
