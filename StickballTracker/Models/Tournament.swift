import Foundation

// MARK: - Tournament (Top Level)

struct Tournament: Identifiable, Codable {
    var id: String
    var name: String
    var teamIds: [String]
    var tiers: [TournamentTier]
    var status: TournamentStatus
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, teamIds: [String] = []) {
        self.id = id
        self.name = name
        self.teamIds = teamIds
        self.tiers = []
        self.status = .setup
        self.createdAt = Date()
    }
}

enum TournamentStatus: String, Codable {
    case setup
    case inProgress
    case completed
}

// MARK: - Tournament Tier (One per day)

struct TournamentTier: Identifiable, Codable {
    var id: String
    var tierNumber: Int              // 1, 2, or 3
    var tierName: String             // "Round 1", "Round 2", "Championship"
    var dayLabel: String             // "Friday", "Saturday", "Sunday"
    var date: Date?
    var teamIds: [String]            // Teams participating in this tier
    var games: [TournamentGame]      // ALL games flat (for schedule view)
    var winnersBracketRounds: [BracketRoundGroup]  // Rounds of game IDs for bracket view
    var losersBracketRounds: [BracketRoundGroup]   // Rounds of game IDs for bracket view
    var championshipGameId: String?
    var ifNecessaryGameId: String?
    var status: TierStatus
    var advancingTeamIds: [String]

    init(
        id: String = UUID().uuidString,
        tierNumber: Int,
        tierName: String,
        dayLabel: String,
        date: Date? = nil,
        teamIds: [String] = []
    ) {
        self.id = id
        self.tierNumber = tierNumber
        self.tierName = tierName
        self.dayLabel = dayLabel
        self.date = date
        self.teamIds = teamIds
        self.games = []
        self.winnersBracketRounds = []
        self.losersBracketRounds = []
        self.championshipGameId = nil
        self.ifNecessaryGameId = nil
        self.status = .upcoming
        self.advancingTeamIds = []
    }

    /// Find a game by ID within this tier
    func game(byId gameId: String) -> TournamentGame? {
        games.first { $0.id == gameId }
    }

    /// Get games for a specific bracket round
    func gamesForWinnersRound(_ roundIndex: Int) -> [TournamentGame] {
        guard roundIndex < winnersBracketRounds.count else { return [] }
        return winnersBracketRounds[roundIndex].gameIds.compactMap { id in game(byId: id) }
    }

    func gamesForLosersRound(_ roundIndex: Int) -> [TournamentGame] {
        guard roundIndex < losersBracketRounds.count else { return [] }
        return losersBracketRounds[roundIndex].gameIds.compactMap { id in game(byId: id) }
    }

    /// All games sorted by scheduled time then game number (for schedule view)
    var sortedGames: [TournamentGame] {
        games.sorted { a, b in
            if let d1 = a.scheduledTime, let d2 = b.scheduledTime {
                if d1 != d2 { return d1 < d2 }
            }
            return a.gameNumber < b.gameNumber
        }
    }
}

enum TierStatus: String, Codable {
    case upcoming
    case inProgress
    case completed
}

// MARK: - Tournament Game (Atomic unit — single game, not a series)

struct TournamentGame: Identifiable, Codable {
    var id: String
    var gameNumber: Int              // Sequential within the tier (Game 1, 2, ... 13)
    var team1Id: String?
    var team2Id: String?
    var team1Score: Int
    var team2Score: Int
    var winnerId: String?
    var loserId: String?
    var playerGameStats: [PlayerGameStats]
    var field: String?
    var scheduledTime: Date?
    var status: GameStatus
    var completedAt: Date?
    var bracketSide: BracketSide
    var feedsWinnerTo: GameLink?
    var feedsLoserTo: GameLink?

    init(
        id: String = UUID().uuidString,
        gameNumber: Int,
        bracketSide: BracketSide = .winners,
        team1Id: String? = nil,
        team2Id: String? = nil
    ) {
        self.id = id
        self.gameNumber = gameNumber
        self.team1Id = team1Id
        self.team2Id = team2Id
        self.team1Score = 0
        self.team2Score = 0
        self.winnerId = nil
        self.loserId = nil
        self.playerGameStats = []
        self.field = nil
        self.scheduledTime = nil
        self.status = .pending
        self.completedAt = nil
        self.bracketSide = bracketSide
        self.feedsWinnerTo = nil
        self.feedsLoserTo = nil
    }
}

enum GameStatus: String, Codable {
    case pending
    case inProgress
    case completed
}

enum BracketSide: String, Codable {
    case winners
    case losers
    case championship
    case ifNecessary
}

struct GameLink: Codable {
    var gameId: String
    var slot: TeamSlot
}

struct BracketRoundGroup: Identifiable, Codable {
    var id: String
    var gameIds: [String]

    init(id: String = UUID().uuidString, gameIds: [String]) {
        self.id = id
        self.gameIds = gameIds
    }
}

enum TeamSlot: String, Codable {
    case team1
    case team2
}

// MARK: - Player Game Stats

struct PlayerGameStats: Identifiable, Codable {
    var id: String
    var playerId: String
    var dongs: Int
    var drops: Int
    var doublePlays: Int
    var salamies: Int

    init(id: String = UUID().uuidString, playerId: String) {
        self.id = id
        self.playerId = playerId
        self.dongs = 0
        self.drops = 0
        self.doublePlays = 0
        self.salamies = 0
    }
}

// MARK: - Fields

enum StickballField: String, CaseIterable, Codable {
    case stonewallJackson = "Stonewall Jackson"
    case williamsburg = "Williamsburg"
    case deadEnd = "Dead End"
    case theSchoolyard = "The Schoolyard"
    case churchLot = "Church Lot"
    case broadwayAlley = "Broadway Alley"
    case theSandlot = "The Sandlot"
    case rooftopDiamond = "Rooftop Diamond"
    case elBarrio = "El Barrio"
    case flatbushField = "Flatbush Field"
}
