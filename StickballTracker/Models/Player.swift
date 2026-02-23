import Foundation

struct Player: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var teamId: String?
    var stats: PlayerStats
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, teamId: String? = nil) {
        self.id = id
        self.name = name
        self.teamId = teamId
        self.stats = PlayerStats()
        self.createdAt = Date()
    }
}

struct PlayerStats: Codable, Hashable {
    var dongs: Int = 0
    var drops: Int = 0
    var doublePlays: Int = 0
    var salamies: Int = 0
    var suds: Int = 0
    var tacos: Int = 0
    var gamesPlayed: Int = 0
}
