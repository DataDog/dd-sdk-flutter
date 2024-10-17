// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Foundation
import XCTest
import Flutter
@testable import datadog_flutter_plugin

enum SupportedContractType {
    case string
    case int
    case int64
    case bool
    case map
    case list

    func createOfType() -> Any {
        switch self {
        case .string: return "fake string"
        case .int: return 1_234
        case .int64: return 1_223_455_123
        case .bool: return false
        case .map: return ["key to": "value"]
        case .list: return [] as [Any]
        }
    }
}

struct Contract {
    let methodName: String
    let requiredParameters: [String: SupportedContractType]

    init(methodName: String, requiredParameters: [String: SupportedContractType]) {
        self.methodName = methodName
        self.requiredParameters = requiredParameters
    }

    func createContractArguments(excluding: String?, additionalArguments: [String: Any]? = nil) -> [String: Any] {
        var arguments: [String: Any] = [:]
        for param in requiredParameters where param.key != excluding {
            arguments[param.key] = param.value.createOfType()
        }
        if let additionalArguments = additionalArguments {
            for addedArg in additionalArguments {
                arguments[addedArg.key] = addedArg.value
            }
        }

        return arguments
    }
}

func testContracts(contracts: [Contract], plugin: FlutterPlugin, additionalArguments: [String: Any]? = nil) {
    func callContract(contract: Contract, arguments: [String: Any], plugin: FlutterPlugin) -> ResultStatus {
        let call = FlutterMethodCall(methodName: contract.methodName, arguments: arguments)
        var resultStatus = ResultStatus.notCalled
        plugin.handle!(call) { result in
            resultStatus = .called(value: result)
        }

        return resultStatus
    }

    for contract in contracts {
        let arguments = contract.createContractArguments(excluding: nil, additionalArguments: additionalArguments)
        let result = callContract(contract: contract, arguments: arguments, plugin: plugin)
        switch result {
        case .called(let value):
            let error = value as? FlutterError
            XCTAssertNotEqual(value as? NSObject, FlutterMethodNotImplemented)
            XCTAssertNil(error, "\(contract.methodName) returned result \(String(describing: error)) on valid call")

        case .notCalled:
            XCTFail("\(contract.methodName) did call result in valid call")
        }

        for param in contract.requiredParameters {
            let arguments = contract.createContractArguments(excluding: param.key,
                                                             additionalArguments: additionalArguments)
            let result = callContract(contract: contract, arguments: arguments, plugin: plugin)
            switch result {
            case .called(let value):
                let error = value as? FlutterError
                XCTAssertNotNil(error)
                XCTAssertEqual(error?.code, FlutterError.DdErrorCodes.contractViolation,
                               // swiftlint:disable:next line_length
                               "\(contract.methodName) did not throw a contact violation when missing parameter \(param)")
                XCTAssertNotNil(error?.message)

            case .notCalled:
                XCTFail("\(contract.methodName) did not throw a contact violation when missing parameter \(param)")
            }
        }
    }
}
