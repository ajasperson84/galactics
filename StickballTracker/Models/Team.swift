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

    static func splitName(_ name: String) -> [String] {
        if name.hasPrefix("Mothership JV") {
            return ["Mothership", String(name.dropFirst("Mothership ".count))]
        }
        if name.hasPrefix("No Mames Wey") && name.count > "No Mames Wey".count {
            return ["No Mames Wey", String(name.dropFirst("No Mames Wey ".count))]
        }
        return [name]
    }
}
