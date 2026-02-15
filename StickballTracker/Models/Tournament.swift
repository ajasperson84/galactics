import Foundation

struct Tournament: Identifiable, Codable {
    var id: String
    var name: String
    var teamIds: [String]
    var bracket: [BracketRound]
    var status: TournamentStatus
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, teamIds: [String] = []) {
        self.id = id
        self.name = name
        self.teamIds = teamIds
        self.bracket = []
        self.status = .setup
        self.createdAt = Date()
    }
}

enum TournamentStatus: String, Codable {
    case setup
    case inProgress
    case completed
}

struct BracketRound: Identifiable, Codable {
    var id: String
    var roundNumber: Int
    var roundName: String
    var matchups: [Matchup]

    init(id: String = UUID().uuidString, roundNumber: Int, roundName: String, matchups: [Matchup]) {
        self.id = id
        self.roundNumber = roundNumber
        self.roundName = roundName
        self.matchups = matchups
    }
}

struct Matchup: Identifiable, Codable {
    var id: String
    var team1Id: String?
    var team2Id: String?
    var games: [Game]
    var winnerId: String?
    var status: MatchupStatus

    init(
        id: String = UUID().uuidString,
        team1Id: String? = nil,
        team2Id: String? = nil
    ) {
        self.id = id
        self.team1Id = team1Id
        self.team2Id = team2Id
        self.games = []
        self.winnerId = nil
        self.status = .pending
    }

    var team1Wins: Int {
        games.filter { $0.winnerId == team1Id }.count
    }

    var team2Wins: Int {
        games.filter { $0.winnerId == team2Id }.count
    }

    var seriesDescription: String {
        "\(team1Wins) - \(team2Wins)"
    }

    var isComplete: Bool {
        team1Wins >= 2 || team2Wins >= 2
    }
}

enum MatchupStatus: String, Codable {
    case pending
    case inProgress
    case completed
}

struct Game: Identifiable, Codable {
    var id: String
    var gameNumber: Int
    var team1Score: Int
    var team2Score: Int
    var winnerId: String?
    var playerGameStats: [PlayerGameStats]
    var field: String?
    var status: GameStatus
    var completedAt: Date?

    init(
        id: String = UUID().uuidString,
        gameNumber: Int
    ) {
        self.id = id
        self.gameNumber = gameNumber
        self.team1Score = 0
        self.team2Score = 0
        self.winnerId = nil
        self.playerGameStats = []
        self.field = nil
        self.status = .notStarted
        self.completedAt = nil
    }
}

enum GameStatus: String, Codable {
    case notStarted
    case inProgress
    case completed
}

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

/// Available fields for game location.
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
