import Foundation

struct Team: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var iconName: String?
    var playerIds: [String]
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, iconName: String? = nil) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.playerIds = []
        self.createdAt = Date()
    }
}
