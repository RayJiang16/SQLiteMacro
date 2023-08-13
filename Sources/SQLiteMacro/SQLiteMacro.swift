import Foundation

//@attached(extension)
@attached(memberAttribute)
@attached(member, names: named(jsonEncoder), named(jsonDecoder), named(encode), named(decode), named(create), named(customEncoding), named(customDecoding), named(Columns), named(init))
public macro SQLiteModel() = #externalMacro(module: "SQLiteMacroMacros", type: "SQLiteModelMacro")


@attached(peer)
public macro ID(key: String = "id") = #externalMacro(module: "SQLiteMacroMacros", type: "SQLiteModelPlaceholdMacro")

@attached(peer)
public macro Field(key: String) = #externalMacro(module: "SQLiteMacroMacros", type: "SQLiteModelPlaceholdMacro")

/// 如果你不想这个变量传入参数里面，可以使用 @Ignore 忽略掉。
@attached(peer)
public macro Ignore() = #externalMacro(module: "SQLiteMacroMacros", type: "SQLiteModelPlaceholdMacro")

@attached(peer)
public macro Timestamp(key: String, on trigger: SQLiteMacroTimestampTrigger) = #externalMacro(module: "SQLiteMacroMacros", type: "SQLiteModelPlaceholdMacro")

@attached(peer)
public macro CodableToData(key: String, defaultValue: String? = nil) = #externalMacro(module: "SQLiteMacroMacros", type: "SQLiteModelPlaceholdMacro")

@attached(peer)
public macro CodableToString(key: String, encoding: String.Encoding = .utf8, defaultValue: String? = nil) = #externalMacro(module: "SQLiteMacroMacros", type: "SQLiteModelPlaceholdMacro")
