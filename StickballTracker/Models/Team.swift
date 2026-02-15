import Foundation

struct Team: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var playerIds: [String]
    var wins: Int
    var losses: Int
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
        self.playerIds = []
        self.wins = 0
        self.losses = 0
        self.createdAt = Date()
    }

    var winPercentage: Double {
        let total = wins + losses
        guard total > 0 else { return 0 }
        return Double(wins) / Double(total)
    }
}
