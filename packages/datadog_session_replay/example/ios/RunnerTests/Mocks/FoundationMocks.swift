//// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation

extension FixedWidthInteger {
    public static func mockRandom() -> Self {
        return .random(in: min...max)
    }

    public static func mockRandom(min: Self = .min, max: Self = .max, otherThan values: Set<Self> = []) -> Self {
        var random: Self = .random(in: min...max)
        while values.contains(random) { random = .random(in: min...max) }
        return random
    }
}

extension Bool {
    public static func mockRandom() -> Bool {
        return .random()
    }

    public static func mockAny() -> Bool {
        return false
    }
}

extension TimeInterval {
    public static let distantFuture = TimeInterval(integerLiteral: .max)

    public static func mockRandomInThePast() -> TimeInterval {
        return random(in: 0..<Date().timeIntervalSinceReferenceDate)
    }
}

extension Double {
    public static func mockAny() -> Double {
        return 0
    }

    public static func mockRandom() -> Double {
        return mockRandom(min: 0, max: .greatestFiniteMagnitude)
    }

    public static func mockRandom(min: Double, max: Double) -> Double {
        return .random(in: min...max)
    }
}

extension Date {
    public static func mockAny() -> Date {
        return Date(timeIntervalSinceReferenceDate: 1)
    }

    public static func mockRandom() -> Date {
        let randomTimeInterval = TimeInterval.random(in: 0..<Date().timeIntervalSince1970)
        return Date(timeIntervalSince1970: randomTimeInterval)
    }

    public static func mockRandomInThePast() -> Date {
        return Date(timeIntervalSinceReferenceDate: TimeInterval.mockRandomInThePast())
    }

    public static func mockSpecificUTCGregorianDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0, second: Int = 0) -> Date {
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = second
        dateComponents.timeZone = TimeZone(abbreviation: "UTC")!
        dateComponents.calendar = Calendar(identifier: .gregorian)
        return dateComponents.date!
    }

    public static func mockDecember15th2019At10AMUTC(addingTimeInterval timeInterval: TimeInterval = 0) -> Date {
        return mockSpecificUTCGregorianDate(year: 2_019, month: 12, day: 15, hour: 10)
            .addingTimeInterval(timeInterval)
    }
}

extension String: AnyMockable, RandomMockable {
    public static func mockAny() -> String {
        return "abc"
    }

    public static func mockRandom() -> String {
        return mockRandom(length: 10)
    }

    public static func mockRandom<Length: BinaryInteger>(length: Length) -> String {
        return mockRandom(among: .alphanumericsAndWhitespace, length: Int(length))
    }

    public static func mockRandom(among characters: RandomStringCharacterSet, length: Int = 10) -> String {
        return characters.random(ofLength: length)
    }

    public static func mockRandom(otherThan values: Set<String> = []) -> String {
        var random: String = .mockRandom()
        while values.contains(random) { random = .mockRandom() }
        return random
    }

    public static func mockRepeating(character: Character, times: Int) -> String {
        let characters = (0..<times).map { _ in character }
        return String(characters)
    }

    public enum RandomStringCharacterSet {
        private static let alphanumericCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        private static let decimalDigitCharacters = "0123456789"

        /// Only letters and numbers (lower and upper cased).
        case alphanumerics
        /// Letters, numbers and whitespace (lower and upper cased).
        case alphanumericsAndWhitespace
        /// Only numbers.
        case decimalDigits
        /// Custom characters.
        case custom(characters: String)

        func random(ofLength length: Int) -> String {
            var characters: String
            switch self {
            case .alphanumerics:
                characters = RandomStringCharacterSet.alphanumericCharacters
            case .alphanumericsAndWhitespace:
                characters = RandomStringCharacterSet.alphanumericCharacters + " "
            case .decimalDigits:
                characters = RandomStringCharacterSet.decimalDigitCharacters
            case .custom(let customCharacters):
                characters = customCharacters
            }

            return String((0..<length).map { _ in characters.randomElement()! })
        }
    }
}

extension FixedWidthInteger where Self: RandomMockable {
    public static func mockRandom() -> Self {
        return .random(in: min...max)
    }

    public static func mockRandom(min: Self = .min, max: Self = .max, otherThan values: Set<Self> = []) -> Self {
        var random: Self = .random(in: min...max)
        while values.contains(random) { random = .random(in: min...max) }
        return random
    }
}

extension ExpressibleByIntegerLiteral where Self: AnyMockable {
    public static func mockAny() -> Self { 0 }
}

extension UInt: AnyMockable, RandomMockable { }
extension UInt8: AnyMockable, RandomMockable { }
extension UInt16: AnyMockable, RandomMockable { }
extension UInt32: AnyMockable, RandomMockable { }
extension UInt64: AnyMockable, RandomMockable { }
extension Int: AnyMockable, RandomMockable { }
extension Int8: AnyMockable, RandomMockable { }
extension Int16: AnyMockable, RandomMockable { }
extension Int32: AnyMockable, RandomMockable { }
extension Int64: AnyMockable, RandomMockable { }

extension Array where Element: RandomMockable {
    public static func mockRandom() -> [Element] where Element: RandomMockable {
        return (0..<10).map { _ in .mockRandom() }
    }

    public static func mockRandom(count: Int) -> [Element] where Element: RandomMockable {
        return (0..<count).map { _ in .mockRandom() }
    }
}
