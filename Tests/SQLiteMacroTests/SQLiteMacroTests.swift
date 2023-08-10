import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(SQLiteMacroMacros)
import SQLiteMacroMacros

let testMacros: [String: Macro.Type] = [
    "SQLiteModel": SQLiteModelMacro.self,
]
#endif

final class SQLiteMacroTests: XCTestCase {
    func testMacro() throws {
        #if canImport(SQLiteMacroMacros)
        assertMacroExpansion(
            """
            @SQLiteModel
            class FooV2 {
                static let jsonEncoder = JSONEncoder()
            }
            """,
            expandedSource: """
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
