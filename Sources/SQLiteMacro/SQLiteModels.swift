//
//  File.swift
//  
//
//  Created by Ray Jiang on 2023/8/10.
//

import Foundation
import SQLite

public enum SQLiteMacroTimestampTrigger {
    case create
    case update
}

public enum SQLiteMacroError: Error {
    case cannotConvertToData
    case cannotConvertToString
    case invalidData
}

public protocol SQLiteModelProtocol {
    
    static func customEncoding(_ item: Self, _ setter: [Setter]) throws -> [Setter]
    static func customDecoding(_ row: Row, _ item: Self) throws -> Self
}
