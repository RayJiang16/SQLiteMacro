//
//  File.swift
//  
//
//  Created by Ray Jiang on 2023/8/9.
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct SQLiteModelMacro {

    public init() {
        
    }
}

// Bug
//extension SQLiteModelMacro: ExtensionMacro {
//    
//    public static func expansion<Declaration: DeclGroupSyntax, Type: TypeSyntaxProtocol, Context: MacroExpansionContext>(
//        of node: AttributeSyntax,
//        attachedTo declaration: Declaration,
//        providingExtensionsOf type: Type,
//        conformingTo protocols: [TypeSyntax],
//        in context: Context
//    ) throws -> [ExtensionDeclSyntax] {
//        let name = getName(providingMembersOf: declaration)
//        let customizeList = getUserCustomizeList(providingMembersOf: declaration)
//        
//        let newExtension = try ExtensionDeclSyntax("extension \(raw: name): SQLiteModelProtocol") {}
//        return [newExtension]
//        
////        return [ExtensionDeclSyntax.init(extendedType: TypeSyntax(stringLiteral: "\(name): SQLiteModelProtocol")) {
////            .init(decl: createCustomEncoding(name: name))
////        }]
//        
////        return [.init(extendedType: TypeSyntax(stringLiteral: "\(name): SQLiteModelProtocol"), memberBlockBuilder: {
////            .init(decl: [customizeList.contains(.customEncoding) ? nil : createCustomEncoding(name: name),
////                         customizeList.contains(.customDecoding) ? nil : createCustomDecoding(name: name)].compactMap { $0 })
////        })]
//    }
//    
//}

// MARK: - MemberAttributeMacro
extension SQLiteModelMacro: MemberAttributeMacro {

    public static func expansion<Declaration: DeclGroupSyntax, MemberDeclaration: DeclSyntaxProtocol, Context: MacroExpansionContext>(
        of node: AttributeSyntax,
        attachedTo declaration: Declaration,
        providingAttributesFor member: MemberDeclaration,
        in context: Context
    ) throws -> [AttributeSyntax] {
        let propertyKeys = ModelKey.allCases.filter { $0.isProperty }.map(\.rawValue)
        if let decl = member.as(VariableDeclSyntax.self) { // Property
            let attribute = decl.attributes?.first?.as(AttributeSyntax.self)?.attributeName.trimmedDescription ?? ""
            let propertyName = decl.bindings.first?.pattern.trimmedDescription ?? ""
            let type = decl.bindings.first?.typeAnnotation?.type.trimmedDescription ?? ""
            let supportTypes = SQLSupportType.allCases.map(\.rawValue)
            
            if propertyKeys.contains(propertyName) {
                return []
            }
            if attribute.isEmpty && !propertyName.isEmpty {
                if supportTypes.contains(type) {
                    return ["@Field(key: \"\(raw: propertyName)\")"]
                } else {
                    return ["@Ignore()"]
                }
            }
            return []
        } else if let _ = member.as(FunctionDeclSyntax.self) { // Function
            return []
        }
        return []
    }
}

// MARK: - MemberMacro
extension SQLiteModelMacro: MemberMacro {
    
    public static func expansion<Declaration: DeclGroupSyntax, Context: MacroExpansionContext>(
        of node: AttributeSyntax,
        providingMembersOf declaration: Declaration,
        in context: Context
    ) throws -> [DeclSyntax] {
        let name = getName(providingMembersOf: declaration)
        let parameters = getParameters(providingMembersOf: declaration)
        let customizeList = getUserCustomizeList(providingMembersOf: declaration)
        return [
            createColumns(),
            createColumnsStruct(parameters),
            customizeList.contains(.jsonEncoder) ? nil : createJSONEncoder(),
            customizeList.contains(.jsonDecoder) ? nil : createJSONDecoder(),
            customizeList.contains(.create) ? nil : createOnTable(parameters),
            customizeList.contains(.encode) ? nil : createEncode(parameters, name: name),
            customizeList.contains(.customEncoding) ? nil : createCustomEncoding(name: name),
            customizeList.contains(.decode) ? nil : createDecode(parameters, name: name),
            customizeList.contains(.customDecoding) ? nil : createCustomDecoding(name: name)
        ].compactMap { $0 }
    }
    
    // MARK: - Get infomation
    
    /// Retrieves the name of a declaration group, targeting both struct and class declarations.
    ///
    /// - Parameter declaration: The declaration group syntax.
    /// - Returns: The name of the struct or class, or an empty string if neither is found.
    private static func getName(providingMembersOf declaration: DeclGroupSyntax) -> String {
        if let name = declaration.as(StructDeclSyntax.self)?.name.trimmedDescription {
            return name
        }
        if let name = declaration.as(ClassDeclSyntax.self)?.name.trimmedDescription {
            return name
        }
        return ""
    }
    
    /// Get all parameters from a declaration group.
    /// - Parameter declaration: The declaration group syntax.
    /// - Returns: An array of `ModelParameter` objects.
    private static func getParameters(providingMembersOf declaration: DeclGroupSyntax) -> [ModelParameter] {
        let supportTypes = SQLSupportType.allCases.map(\.rawValue)
        
        return declaration.memberBlock.members.compactMap {
            $0.decl.as(VariableDeclSyntax.self) // Retrieve property declarations only
        }.filter {
            $0.bindings.first?.accessorBlock == nil // Filtering computed properties
        }.map { decl in
            let type = decl
                .bindings.first?
                .typeAnnotation?
                .type
                .trimmedDescription ?? ""
            let isOptional = decl
                .bindings.first?
                .typeAnnotation?
                .type.as(OptionalTypeSyntax.self) != nil
            let name = decl
                .bindings.first?
                .pattern.as(IdentifierPatternSyntax.self)?
                .trimmedDescription ?? ""
            let wrapper = decl
                .attributes?.first?.as(AttributeSyntax.self)?
                .attributeName
                .trimmedDescription ?? ""
            
            let arguments = getMemberAttributeMacroInfo(arguments: decl.attributes?.first?.as(AttributeSyntax.self)?.arguments)
            let key = findArgument(key: "key", in: arguments, defaultValue: "\"\(name)\"")
            var wrapperType: ModelParameter.WrapperType = .none
            switch wrapper {
            case "ID":
                wrapperType = .id(key: key)
            case "Ignore":
                wrapperType = .ignore
            case "Field":
                wrapperType = .field(key: key)
            case "Timestamp":
                wrapperType = .timestamp(key: key, on: findArgument(key: "on", in: arguments, defaultValue: ".create"))
            case "CodableToData":
                wrapperType = .codableToData(key: key, defaultValue: handleDefaultValue(from: findArgument(key: "defaultValue", in: arguments)))
            case "CodableToString":
                wrapperType = .codableToString(key: key, encoding: findArgument(key: "encoding", in: arguments, defaultValue: ".utf8"), defaultValue: handleDefaultValue(from: findArgument(key: "defaultValue", in: arguments)))
            default:
                if supportTypes.contains(type) {
                    wrapperType = .field(key: key)
                } else {
                    wrapperType = .ignore
                }
            }
            return ModelParameter(name: name, type: type, isOptional: isOptional, wrapperType: wrapperType)
        }
    }
    
    /// Extracts information from attribute macro arguments.
    /// - Parameter arguments: The attribute macro arguments.
    /// - Returns: An array of `MemberAttributeInfo` objects.
    private static func getMemberAttributeMacroInfo(arguments: AttributeSyntax.Arguments?) -> [MemberAttributeInfo] {
        guard let list = arguments?.as(LabeledExprListSyntax.self) else { return [] }
        return list.map {
            .init(name: $0.label?.text, value: $0.expression.trimmedDescription)
        }
    }
    
    /// Finds the value of a specific argument in the array of `MemberAttributeInfo`.
    /// - Parameters:
    ///   - key: The key of the argument to find.
    ///   - arguments: An array of `MemberAttributeInfo` containing attribute arguments.
    /// - Returns: The value of the argument, if found; otherwise, `nil`.
    private static func findArgument(key: String, in arguments: [MemberAttributeInfo]) -> String? {
        return arguments.first(where: { $0.name == key })?.value
    }
    
    /// Finds the value of a specific argument in the array of `MemberAttributeInfo`.
    /// - Parameters:
    ///   - key: The key of the argument to find.
    ///   - arguments: An array of `MemberAttributeInfo` containing attribute arguments.
    ///   - defaultValue: The default value to use if the argument is not found.
    /// - Returns: The value of the argument, or the provided default value if not found.
    private static func findArgument(key: String, in arguments: [MemberAttributeInfo], defaultValue: String) -> String {
        return arguments.first(where: { $0.name == key })?.value ?? defaultValue
    }
    
    /// Handles the default value from a string, removing enclosing double quotes and unescaping escaped quotes.
    ///
    /// - Parameter string: The input string representing the default value.
    /// - Returns: The processed default value string, or `nil` if the input string is `nil`.
    private static func handleDefaultValue(from string: String?) -> String? {
        guard var result = string else { return nil }
        if result.hasPrefix("\"") {
            result.removeFirst()
        }
        if result.hasSuffix("\"") {
            result.removeLast()
        }
        return result.replacingOccurrences(of: "\\\"", with: "\"")
    }
    
    /// Returns a list of ModelKey objects representing the variables or methods that have been manually overridden by the user. This method identifies and excludes these overridden members from code generation.
    ///
    /// - Parameter declaration: The DeclGroupSyntax object containing the member declarations to be analyzed.
    /// - Returns: An array of ModelKey objects representing the customized members.
    private static func getUserCustomizeList(providingMembersOf declaration: DeclGroupSyntax) -> [ModelKey] {
        let propertyKeys = ModelKey.allCases.filter { $0.isProperty }.map(\.rawValue)
        let methodKeys = ModelKey.allCases.filter { !$0.isProperty }.map(\.rawValue)
        var list: [ModelKey] = []
        for member in declaration.memberBlock.members {
            if let decl = member.decl.as(VariableDeclSyntax.self) {
                let name = decl
                    .bindings.first?
                    .pattern.as(IdentifierPatternSyntax.self)?
                    .trimmedDescription ?? ""
                let isStatic = decl.modifiers?.first?.name.trimmedDescription == "static"
                if propertyKeys.contains(name) && isStatic {
                    list.append(ModelKey(rawValue: name)!)
                }
            } else if let decl = member.decl.as(FunctionDeclSyntax.self) {
                let name = decl.name.trimmedDescription
                let isStatic = decl.modifiers?.first?.name.trimmedDescription == "static"
                if methodKeys.contains(name) && isStatic {
                    let parameters = decl.signature.parameterClause.parameters.map { $0.firstName.trimmedDescription }
                    let modelKey = ModelKey(rawValue: name)!
                    if modelKey.parameters == parameters {
                        list.append(modelKey)
                    }
                }
            } else if let _ = member.decl.as(InitializerDeclSyntax.self) {
                list.append(.`init`)
            }
        }
        return list
    }
     
    // MARK: - Generate code
    
    private static func createJSONEncoder() -> DeclSyntax {
        return """
            static let jsonEncoder = JSONEncoder()
            """
    }
    
    private static func createJSONDecoder() -> DeclSyntax {
        return """
            static let jsonDecoder = JSONDecoder()
            """
    }
    
    private static func createColumns() -> DeclSyntax {
        return """
            static let columns = Columns()
            """
    }
    
    private static func createColumnsStruct(_ parameters: [ModelParameter]) -> DeclSyntax {
        let code = parameters.filter {
            $0.wrapperType.available
        }.map {
            let type: String
            switch $0.wrapperType {
            case .codableToData:
                type = $0.isOptional ? "Data?" : "Data"
            case .codableToString:
                type = $0.isOptional ? "String?" : "String"
            default:
                type = $0.type
            }
            return "\tlet \($0.name) = Expression<\(type)>(\($0.wrapperType.key))"
        }.joined(separator: "\n")
        
        return """
            struct Columns {
            \(raw: code)
            }
            """
    }
    
    private static func createOnTable(_ parameters: [ModelParameter]) -> DeclSyntax {
        let code = parameters.filter {
            $0.wrapperType.available
        }.map {
            var primaryKey = ""
            if case .id = $0.wrapperType {
                primaryKey = ", primaryKey: true"
            }
            return "\t\tt.column(columns.\($0.name)\(primaryKey))"
        }.joined(separator: "\n")
        
        return
            """
            
            static func create(on db: Connection, table: Table) throws {
                try db.run(table.create(ifNotExists: true) { t in
            \(raw: code)
                })
            }
            
            """
    }
    
    private static func createEncode(_ parameters: [ModelParameter], name: String) -> DeclSyntax {
        
        let helperCode = parameters.filter { $0.wrapperType.isCodable }.isEmpty ? "" : """
            
            func encode<T>(_ value: T) throws -> Data where T : Encodable {
                return try jsonEncoder.encode(value)
            }
                
            func encodeToJSON<T>(_ value: T, encoding: String.Encoding) throws -> String where T : Encodable {
                let data = try jsonEncoder.encode(value)
                if let str = String(data: data, encoding: encoding) {
                    return str
                } else {
                    throw SQLiteMacroError.cannotConvertToString
                }
            }
            
            """
        
        let code = parameters.filter {
            $0.wrapperType.available
        }.map {
            let defaultCode = "columns.\($0.name) <- item.\($0.name)"
            
            switch $0.wrapperType {
            case .timestamp(_, let target):
                if target == ".create" && $0.isOptional {
                    return "columns.\($0.name) <- item.\($0.name) ?? Date()"
                } else if target == ".update" && $0.isOptional {
                    return "columns.\($0.name) <- Date()"
                } else {
                    return defaultCode
                }
            case .codableToData(_, let defaultValue):
                let tryCode = defaultValue != nil && $0.isOptional ? "try?" : "try"
                let defaultValueCode = defaultValue != nil && $0.isOptional ? " ?? \(defaultValue!)" : ""
                return "columns.\($0.name) <- (\(tryCode) encode(item.\($0.name)\(defaultValueCode)))"
            case .codableToString(_, let encoding, let defaultValue):
                let tryCode = defaultValue != nil && $0.isOptional ? "try?" : "try"
                let defaultValueCode = defaultValue != nil && $0.isOptional ? " ?? \(defaultValue!)" : ""
                return "columns.\($0.name) <- (\(tryCode) encodeToJSON(item.\($0.name)\(defaultValueCode), encoding: \(encoding)))"
            default:
                return defaultCode
            }
        }.joined(separator: ",\n")
        
        return
            """
            
            static func encode(_ item: \(raw: name)) throws -> [Setter] {
                \(raw: helperCode)
                let setter = [
                    \(raw: code)
                ]
                return try customEncoding(item, setter)
            }
            
            """
    }
    
    private static func createDecode(_ parameters: [ModelParameter], name: String) -> DeclSyntax {

        let helperCode = parameters.filter { $0.wrapperType.isCodable }.isEmpty ? "" : """
            
            func decode<T>(_ type: T.Type,
                           from string: String?,
                           using encoding: String.Encoding) throws -> T where T : Decodable {
                guard let data = string?.data(using: encoding) else {
                    throw SQLiteMacroError.cannotConvertToData
                }
                return try decode(type, from: data)
            }
            
            func decode<T>(_ type: T.Type,
                           from data: Data?) throws -> T where T : Decodable {
                guard let data = data else { throw SQLiteMacroError.invalidData }
                return try jsonDecoder.decode(type, from: data)
            }
            
            """
        
        let code = parameters.filter {
            $0.wrapperType.available
        }.map {
            switch $0.wrapperType {
            case .codableToData(_, let defaultValue):
                let tryCode = $0.isOptional || (defaultValue != nil) ? "try?" : "try"
                let defaultValueCode = defaultValue != nil ? " ?? \(defaultValue!)" : ""
                return "item.\($0.name) = (\(tryCode) decode(\($0.type).self, from: row[columns.\($0.name)]))\(defaultValueCode)"
            case .codableToString(_, let encoding, let defaultValue):
                let tryCode = $0.isOptional || (defaultValue != nil) ? "try?" : "try"
                let defaultValueCode = defaultValue != nil ? " ?? \(defaultValue!)" : ""
                return "item.\($0.name) = (\(tryCode) decode(\($0.type).self, from: row[columns.\($0.name)], using: \(encoding)))\(defaultValueCode)"
            default:
                return "item.\($0.name) = row[columns.\($0.name)]"
            }
        }.joined(separator: "\n")
        
        return
            """
            
            static func decode(_ row: Row) throws -> \(raw: name) {
                \(raw: helperCode)
                var item = \(raw: name)()
                \(raw: code)
                return try customDecoding(row, item)
            }
            
            """
    }
    
    private static func createCustomEncoding(name: String) -> DeclSyntax {
        return """
            static func customEncoding(_ item: \(raw: name), _ setter: [Setter]) throws -> [Setter] {
                return setter
            }
            """
    }
    
    private static func createCustomDecoding(name: String) -> DeclSyntax {
        return """
            static func customDecoding(_ row: Row, _ item: \(raw: name)) throws -> \(raw: name) {
                return item
            }
            """
    }
}

/// A marker attribute used solely for adding macros to parameters, facilitating code generation.
public struct SQLiteModelPlaceholdMacro: PeerMacro {
    
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return []
    }
}
