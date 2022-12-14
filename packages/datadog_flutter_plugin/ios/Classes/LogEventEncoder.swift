// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Foundation
import Datadog
import DictionaryCoder

// Because iOS and Android differ so much in the structure of this event,
// we have to fixup / unfixup the positions of several members
func logEventToFlutterDictionary(event: LogEvent) -> [String: Any]? {
    let encoder = DictionaryEncoder()
    guard var encoded = try? encoder.encode(event) else {
        return nil
    }

    nest(property: "logger.name", inDictionary: &encoded)
    nest(property: "logger.version", inDictionary: &encoded)
    nest(property: "logger.thread_name", inDictionary: &encoded)

    nest(property: "usr.id", inDictionary: &encoded)
    nest(property: "usr.name", inDictionary: &encoded)
    nest(property: "usr.email", inDictionary: &encoded)

    nest(property: "error.kind", inDictionary: &encoded)
    nest(property: "error.message", inDictionary: &encoded)
    nest(property: "error.stack", inDictionary: &encoded)

    // Switch "date" to a string (normally an int)
    encoded["date"] = event.date.description

    return encoded
}

private func nest(property: String, inDictionary dictionary: inout [String: Any]) {
    var parts = property.split(separator: ".")
    if let value = dictionary[property] {
        var valueAccumulator = [String(parts.removeLast()): value]

        for part in parts.reversed() {
            valueAccumulator = [String(part): valueAccumulator]
        }

        func dictionaryMerge(current: Any, new: Any) -> Any {
            if let current = current as? [String: Any],
               let new = new as? [String: Any] {
                return current.merging(new, uniquingKeysWith: dictionaryMerge)
            }
            return new
        }

        dictionary.merge(valueAccumulator, uniquingKeysWith: dictionaryMerge)

        dictionary.removeValue(forKey: property)
    }
}
