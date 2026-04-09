import Foundation
import FirebaseFirestore
import Combine

/// Cloud sync service using Firebase Firestore for real-time multi-user synchronization.
/// Also persists data locally as JSON so it survives app restarts even without connectivity.
@MainActor
class CloudSyncService: ObservableObject {
    @Published var players: [Player] = []
    @Published var teams: [Team] = []
    @Published var tournament: Tournament?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []

    // MARK: - Local Persistence Paths

    private static var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private static var playersFile: URL { documentsDir.appendingPathComponent("players.json") }
    private static var teamsFile: URL { documentsDir.appendingPathComponent("teams.json") }
    private static var tournamentFile: URL { documentsDir.appendingPathComponent("tournament.json") }

    init() {
        loadFromDisk()
        attachListeners()
    }

    // MARK: - Local JSON Persistence

    private func loadFromDisk() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: Self.playersFile),
           let saved = try? decoder.decode([Player].self, from: data) {
            players = saved
        }

        if let data = try? Data(contentsOf: Self.teamsFile),
           let saved = try? decoder.decode([Team].self, from: data) {
            teams = saved
        }

        if let data = try? Data(contentsOf: Self.tournamentFile),
           let saved = try? decoder.decode(Tournament.self, from: data) {
            tournament = saved
        }
    }

    private func savePlayers() {
        save(players, to: Self.playersFile)
    }

    private func saveTeams() {
        save(teams, to: Self.teamsFile)
    }

    private func saveTournament() {
        if let tournament {
            save(tournament, to: Self.tournamentFile)
        } else {
            try? FileManager.default.removeItem(at: Self.tournamentFile)
        }
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Real-time Listeners

    private func attachListeners() {
        let playersListener = db.collection("players")
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    guard let documents = snapshot?.documents else { return }
                    self.players = documents.compactMap { try? $0.data(as: Player.self) }
                    self.savePlayers()
                }
            }
        listeners.append(playersListener)

        let teamsListener = db.collection("teams")
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    guard let documents = snapshot?.documents else { return }
                    self.teams = documents.compactMap { try? $0.data(as: Team.self) }
                    self.saveTeams()
                }
            }
        listeners.append(teamsListener)

        let tournamentListener = db.collection("tournaments")
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.tournament = snapshot?.documents.first.flatMap { try? $0.data(as: Tournament.self) }
                    self.saveTournament()
                }
            }
        listeners.append(tournamentListener)
    }

    // MARK: - Player Operations

    func addPlayer(name: String, teamId: String? = nil) async {
        let player = Player(name: name, teamId: teamId)
        do {
            try db.collection("players").document(player.id).setData(from: player)
            if let teamId,
               var team = teams.first(where: { $0.id == teamId }),
               !team.playerIds.contains(player.id) {
                team.playerIds.append(player.id)
                try db.collection("teams").document(team.id).setData(from: team)
            }
        } catch {
            errorMessage = "Failed to add player: \(error.localizedDescription)"
        }
    }

    func updatePlayer(_ player: Player) async {
        do {
            try db.collection("players").document(player.id).setData(from: player)
        } catch {
            errorMessage = "Failed to update player: \(error.localizedDescription)"
        }
    }

    func deletePlayer(_ player: Player) async {
        do {
            try await db.collection("players").document(player.id).delete()
            if let teamId = player.teamId,
               var team = teams.first(where: { $0.id == teamId }) {
                team.playerIds.removeAll { $0 == player.id }
                try db.collection("teams").document(team.id).setData(from: team)
            }
        } catch {
            errorMessage = "Failed to delete player: \(error.localizedDescription)"
        }
    }

    func updatePlayerStats(playerId: String, gameStats: PlayerGameStats) async {
        guard var player = players.first(where: { $0.id == playerId }) else { return }
        player.stats.dongs += gameStats.dongs
        player.stats.drops += gameStats.drops
        player.stats.doublePlays += gameStats.doublePlays
        player.stats.salamies += gameStats.salamies
        player.stats.gamesPlayed += 1
        await updatePlayer(player)
    }

    // MARK: - Team Operations

    func addTeam(name: String) async {
        let team = Team(name: name)
        do {
            try db.collection("teams").document(team.id).setData(from: team)
        } catch {
            errorMessage = "Failed to add team: \(error.localizedDescription)"
        }
    }

    func updateTeam(_ team: Team) async {
        do {
            try db.collection("teams").document(team.id).setData(from: team)
        } catch {
            errorMessage = "Failed to update team: \(error.localizedDescription)"
        }
    }

    func deleteTeam(_ team: Team) async {
        do {
            for var player in players where player.teamId == team.id {
                player.teamId = nil
                try db.collection("players").document(player.id).setData(from: player)
            }
            try await db.collection("teams").document(team.id).delete()
        } catch {
            errorMessage = "Failed to delete team: \(error.localizedDescription)"
        }
    }

    func assignPlayerToTeam(playerId: String, teamId: String?) async {
        guard var player = players.first(where: { $0.id == playerId }) else { return }

        // Remove from old team
        if let oldTeamId = player.teamId,
           var oldTeam = teams.first(where: { $0.id == oldTeamId }) {
            oldTeam.playerIds.removeAll { $0 == playerId }
            await updateTeam(oldTeam)
        }

        player.teamId = teamId

        // Add to new team
        if let teamId,
           var newTeam = teams.first(where: { $0.id == teamId }) {
            if !newTeam.playerIds.contains(playerId) {
                newTeam.playerIds.append(playerId)
            }
            await updateTeam(newTeam)
        }

        await updatePlayer(player)
    }

    // MARK: - Tournament Operations

    func createTournament(name: String, matchups: [(String, String, Date?, String?)]) async {
        let allTeamIds = matchups.flatMap { [$0.0, $0.1] }
        var tournament = Tournament(name: name, teamIds: allTeamIds)
        tournament.bracket = generateBracketFromMatchups(matchups)
        tournament.status = .inProgress
        do {
            try db.collection("tournaments").document(tournament.id).setData(from: tournament)
        } catch {
            errorMessage = "Failed to create tournament: \(error.localizedDescription)"
        }
    }

    func updateTournament(_ tournament: Tournament) async {
        do {
            try db.collection("tournaments").document(tournament.id).setData(from: tournament)
        } catch {
            errorMessage = "Failed to update tournament: \(error.localizedDescription)"
        }
    }

    func deleteTournament() async {
        guard let tournament else { return }
        do {
            try await db.collection("tournaments").document(tournament.id).delete()
        } catch {
            errorMessage = "Failed to delete tournament: \(error.localizedDescription)"
        }
    }

    func recordGameResult(
        roundIndex: Int,
        matchupIndex: Int,
        gameIndex: Int,
        team1Score: Int,
        team2Score: Int,
        field: String?,
        gameDate: Date?,
        playerStats: [PlayerGameStats]
    ) async {
        guard var tournament else { return }
        guard roundIndex < tournament.bracket.count,
              matchupIndex < tournament.bracket[roundIndex].matchups.count
        else { return }

        var matchup = tournament.bracket[roundIndex].matchups[matchupIndex]

        if gameIndex < matchup.games.count {
            matchup.games[gameIndex].team1Score = team1Score
            matchup.games[gameIndex].team2Score = team2Score
            matchup.games[gameIndex].playerGameStats = playerStats
            matchup.games[gameIndex].field = field
            matchup.games[gameIndex].gameDate = gameDate
            matchup.games[gameIndex].status = .completed
            matchup.games[gameIndex].completedAt = Date()
            if team1Score > team2Score {
                matchup.games[gameIndex].winnerId = matchup.team1Id
            } else if team2Score > team1Score {
                matchup.games[gameIndex].winnerId = matchup.team2Id
            }
        } else {
            var game = Game(gameNumber: gameIndex + 1)
            game.team1Score = team1Score
            game.team2Score = team2Score
            game.playerGameStats = playerStats
            game.field = field
            game.gameDate = gameDate
            game.status = .completed
            game.completedAt = Date()
            if team1Score > team2Score {
                game.winnerId = matchup.team1Id
            } else if team2Score > team1Score {
                game.winnerId = matchup.team2Id
            }
            matchup.games.append(game)
        }

        // Check if series is decided (best of 3)
        if matchup.team1Wins >= 2 {
            matchup.winnerId = matchup.team1Id
            matchup.status = .completed
        } else if matchup.team2Wins >= 2 {
            matchup.winnerId = matchup.team2Id
            matchup.status = .completed
        } else {
            matchup.status = .inProgress
        }

        tournament.bracket[roundIndex].matchups[matchupIndex] = matchup

        // Advance winner to next round
        if let winnerId = matchup.winnerId, roundIndex + 1 < tournament.bracket.count {
            let nextMatchupIndex = matchupIndex / 2
            if nextMatchupIndex < tournament.bracket[roundIndex + 1].matchups.count {
                if matchupIndex % 2 == 0 {
                    tournament.bracket[roundIndex + 1].matchups[nextMatchupIndex].team1Id = winnerId
                } else {
                    tournament.bracket[roundIndex + 1].matchups[nextMatchupIndex].team2Id = winnerId
                }
            }
        }

        // Check if tournament is complete
        if let lastRound = tournament.bracket.last,
           lastRound.matchups.allSatisfy({ $0.status == .completed }) {
            tournament.status = .completed
        }

        // Accumulate player stats
        for stats in playerStats {
            await updatePlayerStats(playerId: stats.playerId, gameStats: stats)
        }

        await updateTournament(tournament)
    }

    // MARK: - Bracket Generation

    private func generateBracketFromMatchups(_ matchups: [(String, String, Date?, String?)]) -> [BracketRound] {
        let firstRoundMatchups = matchups.map {
            Matchup(team1Id: $0.0, team2Id: $0.1, scheduledDate: $0.2, scheduledField: $0.3)
        }

        var rounds: [BracketRound] = []
        let totalRounds = max(1, Int(ceil(log2(Double(matchups.count)))) + 1)
        let roundNames = generateRoundNames(totalRounds: totalRounds)

        rounds.append(BracketRound(roundNumber: 1, roundName: roundNames[0], matchups: firstRoundMatchups))

        var numMatchups = matchups.count / 2
        var roundNum = 2
        while numMatchups >= 1 {
            let emptyMatchups = (0..<numMatchups).map { _ in Matchup() }
            let nameIndex = min(roundNum - 1, roundNames.count - 1)
            rounds.append(BracketRound(roundNumber: roundNum, roundName: roundNames[nameIndex], matchups: emptyMatchups))
            numMatchups /= 2
            roundNum += 1
        }

        return rounds
    }

    private func generateRoundNames(totalRounds: Int) -> [String] {
        (0..<totalRounds).map { i in
            switch totalRounds - i {
            case 1: return "Championship"
            case 2: return "Semifinals"
            case 3: return "Quarterfinals"
            default: return "Round \(i + 1)"
            }
        }
    }

    // MARK: - Utility

    func playersForTeam(_ teamId: String) -> [Player] {
        players.filter { $0.teamId == teamId }
    }

    func team(for teamId: String) -> Team? {
        teams.first { $0.id == teamId }
    }

    func player(for playerId: String) -> Player? {
        players.first { $0.id == playerId }
    }

    func unassignedPlayers() -> [Player] {
        players.filter { $0.teamId == nil }
    }
}
