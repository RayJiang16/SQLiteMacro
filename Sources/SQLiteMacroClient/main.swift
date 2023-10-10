import Foundation
import SQLite
import SQLiteMacro

@SQLiteModel
struct Foo: SQLiteModelProtocol {
    
    @ID()
    var id: UUID = .init()
    @Field(key: "name_1")
    var name: String?
    @Timestamp(key: "created_at", on: .create)
    var created_at: Date?
    @Timestamp(key: "updated_at", on: .update)
    var updated_at: Date?
//    @CodableToString(key: "coo", defaultValue: ".init(xxx: \"123\")")
//    var coo: Coo?
//    @CodableToData(key: "coo_list", defaultValue: "[]")
//    var cooList: [Coo] = []
    var test: String?
    
    var coo1: Coo?
    
    static var jsonEncoder: JSONEncoder = {
        return JSONEncoder()
    }()
    
//    static let jsonEncoder = JSONEncoder()
//    static let jsonDecoder = JSONDecoder()
    
}


struct Coo: Codable {
    
    let xxx: String
}


