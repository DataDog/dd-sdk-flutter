// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Foundation

internal func castFlutterAttributesToSwift(_ flutterAttributes: [String: Any?]) -> [String: Encodable] {
  var casted: [String: Encodable] = [:]

  flutterAttributes.forEach { key, value in
    if let value = value {
      casted[key] = castAnyToEncodable(value)
    }
  }

  return casted
}

// swiftlint:disable:next cyclomatic_complexity
internal func castAnyToEncodable(_ flutterAny: Any) -> Encodable {
  switch flutterAny {
  case let number as NSNumber:
    if CFGetTypeID(number) == CFBooleanGetTypeID() {
      return CFBooleanGetValue(number)
    } else {
      switch CFNumberGetType(number) {
      case .charType:
        return number.uint8Value
      case .sInt8Type:
        return number.int8Value
      case .sInt16Type:
        return number.int16Value
      case .sInt32Type:
        return number.int32Value
      case .sInt64Type:
        return number.int64Value
      case .shortType:
        return number.uint16Value
      case .longType:
        return number.uint32Value
      case .longLongType:
        return number.uint64Value
      case .intType, .nsIntegerType, .cfIndexType:
        return number.intValue
      case .floatType, .float32Type:
        return number.floatValue
      case .doubleType, .float64Type, .cgFloatType:
        return number.doubleValue
      @unknown default:
        return DdFlutterEncodable(flutterAny)
      }
    }
  case let string as String:
    return string
  default:
    return DdFlutterEncodable(flutterAny)
  }
}

// This is similar to AnyEncodable, but for simplicity, it only looks for types
// that Flutter will send from MethodChannels
internal class DdFlutterEncodable: Encodable {
  public let value: Any

  init(_ value: Any) {
    self.value = value
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch value {
    case let number as NSNumber:
      try encodeNSNumber(number, into: &container)
    case let string as String:
      try container.encode(string)
    case let array as [Any]:
      try container.encode(array.map { DdFlutterEncodable($0) })
    case let dictionary as [String: Any]:
      try container.encode(dictionary.mapValues { DdFlutterEncodable($0) })
    default:
      let context = EncodingError.Context(
        codingPath: container.codingPath,
        // swiftlint:disable:next line_length
        debugDescription: "Value \(value) cannot be encoded - \(type(of: value)) is not supported by `DdFlutterEncodable`."
      )
      throw EncodingError.invalidValue(value, context)
    }
  }
}

// swiftlint:disable:next cyclomatic_complexity
private func encodeNSNumber(_ number: NSNumber, into container: inout SingleValueEncodingContainer) throws {
  if CFGetTypeID(number) == CFBooleanGetTypeID() {
    try container.encode(CFBooleanGetValue(number))
  } else {
    switch CFNumberGetType(number) {
    case .charType:
      try container.encode(number.uint8Value)
    case .sInt8Type:
      try container.encode(number.int8Value)
    case .sInt16Type:
      try container.encode(number.int16Value)
    case .sInt32Type:
      try container.encode(number.int32Value)
    case .sInt64Type:
      try container.encode(number.int64Value)
    case .shortType:
      try container.encode(number.uint16Value)
    case .longType:
      try container.encode(number.uint32Value)
    case .longLongType:
      try container.encode(number.uint64Value)
    case .intType, .nsIntegerType, .cfIndexType:
      try container.encode(number.intValue)
    case .floatType, .float32Type:
      try container.encode(number.floatValue)
    case .doubleType, .float64Type, .cgFloatType:
      try container.encode(number.doubleValue)
    @unknown default:
      return
    }
  }
}
