import Foundation

struct Team: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var playerIds: [String]
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
        self.playerIds = []
        self.createdAt = Date()
    }
}
