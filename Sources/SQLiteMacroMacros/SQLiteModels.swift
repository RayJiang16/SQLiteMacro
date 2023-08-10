//
//  File.swift
//  
//
//  Created by Ray Jiang on 2023/8/9.
//

import Foundation

struct MemberAttributeInfo {
    let name: String?
    let value: String
}

struct ModelParameter {
    
    enum WrapperType: Equatable {
        case none
        case ignore
        case id(key: String)
        case field(key: String)
        case timestamp(key: String, on: String)
        case codableToData(key: String, defaultValue: String?)
        case codableToString(key: String, encoding: String, defaultValue: String?)
        
        var key: String {
            switch self {
            case .none, .ignore: return ""
            case .id(let key): return key
            case .field(let key): return key
            case .timestamp(let key, _): return key
            case .codableToData(let key, _): return key
            case .codableToString(let key, _, _): return key
            }
        }
        
        var available: Bool {
            !(self == .none || self == .ignore)
        }
        
        var isCodable: Bool {
            switch self {
            case .codableToData, .codableToString: return true
            default: return false
            }
        }
    }
    
    let name: String
    let type: String
    let isOptional: Bool
    let wrapperType: WrapperType
    
    init(name: String, type: String, isOptional: Bool, wrapperType: WrapperType = .none) {
        self.name = name
        self.type = type
        self.isOptional = isOptional
        self.wrapperType = wrapperType
    }
}

enum ModelKey: String, CaseIterable {
    
    case jsonEncoder
    case jsonDecoder
    
    case encode
    case decode
    case customEncoding
    case customDecoding
    case create
    case `init`
    
    var isProperty: Bool {
        return self == .jsonEncoder || self == .jsonDecoder
    }
    
    var parameters: [String] {
        switch self {
        case .encode, .decode:
            return ["_"]
        case .customEncoding, .customDecoding:
            return ["_", "_"]
        case .create:
            return ["on", "table"]
        case .`init`:
            return []
        default:
            return []
        }
    }
}

enum SQLSupportType: String, CaseIterable {
    case Int
    case Int64
    case Double
    case String
    case URL
    case UUID
    case Date
    case Data
}
