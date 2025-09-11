//
//  JSONConvertible.swift
//  ExponeaSDKShared
//
//  Created by Dominik Hadl on 23/05/2018.
//  Copyright © 2018 Exponea. All rights reserved.
//

import Foundation

public protocol JSONConvertible {
    var jsonValue: JSONValue { get }
}

extension NSString: JSONConvertible {
    public var jsonValue: JSONValue {
        return .string(self as String)
    }
}

extension String: JSONConvertible {
    public var jsonValue: JSONValue {
        return .string(self)
    }
}
extension Bool: JSONConvertible {
    public var jsonValue: JSONValue {
        return .bool(self)
    }
}

extension Int: JSONConvertible {
    public var jsonValue: JSONValue {
        return .int(self)
    }
}
extension Double: JSONConvertible {
    public var jsonValue: JSONValue {
        guard self.isFinite else {
            return .null("")
        }
        return .double(self)
    }
}
extension NSNull: JSONConvertible {
    public var jsonValue: JSONValue {
        return .null("")
    }
}

extension Dictionary: JSONConvertible where Key == String, Value == JSONConvertible {
    public var jsonValue: JSONValue {
        return .dictionary(self.mapValues({ $0.jsonValue }))
    }
}

extension Array: JSONConvertible where Element == JSONConvertible {
    public var jsonValue: JSONValue {
        return .array(self.map({ $0.jsonValue }))
    }
}

public indirect enum JSONValue: Sendable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
    case dictionary([String: JSONValue])
    case array([JSONValue])
    case null(String)

    public static func convert(value: Any) -> JSONValue? {
        var result: JSONValue?
        switch value {
        case let castedValue as Bool: result = .bool(castedValue)
        case let castedValue as Int: result = .int(castedValue)
        case let castedValue as Double where castedValue.isFinite: result = .double(castedValue)
        case let castedValue as String: result = .string(castedValue)
        case let castedValue as [Any]: result = .array(convert(castedValue))
        case let castedValue as [String: Any]: result = .dictionary(convert(castedValue))
        default:
            Exponea.logger.log(.warning, message: "Can't convert value to JSONValue: \(value).")
        }
        return result
    }

    public static func convert(_ dictionary: [String: Any]) -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]
        for (key, value) in dictionary {
            if let castedValue = convert(value: value) {
                result[key] = castedValue
            }
        }
        return result
    }

    public static func convert(_ array: [Any]) -> [JSONValue] {
        var result: [JSONValue] = []
        for value in array {
            if let castedValue = convert(value: value) {
                result.append(castedValue)
            }
        }
        return result
    }
}

public extension JSONValue {
    var rawValue: Any {
        switch self {
        case .string(let string): return string
        case .bool(let bool): return bool
        case .int(let int): return int
        case .double(let double): return double.isFinite ? double : NSNull()
        case .dictionary(let dictionary): return dictionary.mapValues { $0.rawValue }
        case .array(let array): return array.map { $0.rawValue }
        case .null(_): return NSNull()
        }
    }

    var jsonConvertible: JSONConvertible {
        switch self {
        case .string(let string): return string
        case .bool(let bool): return bool
        case .int(let int): return int
        case .double(let double): return double.isFinite ? double : NSNull()
        case .dictionary(let dictionary): return dictionary.mapValues { $0.jsonConvertible }
        case .array(let array): return array.map { $0.jsonConvertible }
        case .null(_): return NSNull()
        }
    }
}

extension JSONValue: Codable, Equatable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null("")
            return
        }

        do {
            self = .dictionary(try container.decode([String: JSONValue].self))
        } catch DecodingError.typeMismatch {
            do {
                self = .array(try container.decode([JSONValue].self))
            } catch DecodingError.typeMismatch {
                do {
                    self = .string(try container.decode(String.self))
                } catch DecodingError.typeMismatch {
                    do {
                        self = .int(try container.decode(Int.self))
                    } catch {
                        do {
                            let double = try container.decode(Double.self)
                            if double.isFinite {
                                self = .double(double)
                            } else {
                                self = .null("")
                            }
                        } catch {
                            self = .bool(try container.decode(Bool.self))
                        }
                    }
                }
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let int): try container.encode(int)
        case .string(let string): try container.encode(string)
        case .array(let array): try container.encode(array)
        case .bool(let bool): try container.encode(bool)
        case .double(let double):
            if double.isFinite {
                try container.encode(double)
            }
        case .dictionary(let dictionary): try container.encode(dictionary)
        case .null(_): try container.encodeNil()
        }
    }

    public static func == (_ left: JSONValue, _ right: JSONValue) -> Bool {
        switch (left, right) {
        case (.int(let int1), .int(let int2)): return int1 == int2
        case (.bool(let bool1), .bool(let bool2)): return bool1 == bool2
        case (.double(let double1), .double(let double2)): return double1 == double2
        case (.string(let string1), .string(let string2)): return string1 == string2
        case (.array(let array1), .array(let array2)): return array1 == array2
        case (.dictionary(let dict1), .dictionary(let dict2)): return dict1 == dict2
        case (.null(_), .null(_)): return true
        default: return false
        }
    }
}

public extension JSONValue {
    var objectValue: NSObject {
        switch self {
        case .bool(let bool): return NSNumber(value: bool)
        case .int(let int): return NSNumber(value: int)
        case .string(let string): return NSString(string: string)
        case .array(let array): return array.map({ $0.objectValue }) as NSArray
        case .double(let double): return double.isFinite ? NSNumber(value: double) : NSNull()
        case .dictionary(let dictionary): return dictionary.mapValues({ $0.objectValue }) as NSDictionary
        case .null(_): return NSNull()
        }
    }
}
