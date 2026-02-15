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
    var atBats: Int = 0
    var hits: Int = 0
    var singles: Int = 0
    var doubles: Int = 0
    var triples: Int = 0
    var homeRuns: Int = 0
    var runs: Int = 0
    var rbi: Int = 0
    var strikeouts: Int = 0
    var walks: Int = 0
    var gamesPlayed: Int = 0

    var battingAverage: Double {
        guard atBats > 0 else { return 0 }
        return Double(hits) / Double(atBats)
    }

    var sluggingPercentage: Double {
        guard atBats > 0 else { return 0 }
        let totalBases = singles + (doubles * 2) + (triples * 3) + (homeRuns * 4)
        return Double(totalBases) / Double(atBats)
    }

    var onBasePercentage: Double {
        let plateAppearances = atBats + walks
        guard plateAppearances > 0 else { return 0 }
        return Double(hits + walks) / Double(plateAppearances)
    }
}
