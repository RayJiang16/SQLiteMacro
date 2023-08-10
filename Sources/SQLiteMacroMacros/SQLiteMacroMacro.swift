import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct SQLiteMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SQLiteModelMacro.self,
        SQLiteModelPlaceholdMacro.self
    ]
}
