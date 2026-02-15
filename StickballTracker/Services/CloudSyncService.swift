import Foundation
import Combine

/// Data service with local JSON persistence.
/// Data is saved to the app's documents directory and loads on launch.
/// To add cloud sync later, swap the save/load methods for Firebase Firestore calls.
@MainActor
class CloudSyncService: ObservableObject {
    @Published var players: [Player] = []
    @Published var teams: [Team] = []
    @Published var tournament: Tournament?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let saveQueue = DispatchQueue(label: "com.stickball.save", qos: .utility)

    init() {
        loadAll()
    }

    // MARK: - Persistence

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func save<T: Encodable>(_ value: T, to filename: String) {
        let url = Self.documentsURL.appendingPathComponent(filename)
        saveQueue.async {
            do {
                let data = try JSONEncoder().encode(value)
                try data.write(to: url, options: .atomic)
            } catch {
                print("Save error (\(filename)): \(error)")
            }
        }
    }

    private func load<T: Decodable>(_ type: T.Type, from filename: String) -> T? {
        let url = Self.documentsURL.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func loadAll() {
        players = load([Player].self, from: "players.json") ?? []
        teams = load([Team].self, from: "teams.json") ?? []
        tournament = load(Tournament.self, from: "tournament.json")
    }

    private func savePlayers() { save(players, to: "players.json") }
    private func saveTeams() { save(teams, to: "teams.json") }
    private func saveTournament() { save(tournament, to: "tournament.json") }

    // MARK: - Player Operations

    func addPlayer(name: String, teamId: String? = nil) async {
        var player = Player(name: name, teamId: teamId)
        players.append(player)
        players.sort { $0.name.localizedCompare($1.name) == .orderedAscending }

        if let teamId, let idx = teams.firstIndex(where: { $0.id == teamId }) {
            if !teams[idx].playerIds.contains(player.id) {
                teams[idx].playerIds.append(player.id)
                saveTeams()
            }
        }
        savePlayers()
    }

    func updatePlayer(_ player: Player) async {
        if let idx = players.firstIndex(where: { $0.id == player.id }) {
            players[idx] = player
        }
        savePlayers()
    }

    func deletePlayer(_ player: Player) async {
        players.removeAll { $0.id == player.id }
        // Remove from any team
        if let teamId = player.teamId,
           let idx = teams.firstIndex(where: { $0.id == teamId }) {
            teams[idx].playerIds.removeAll { $0 == player.id }
            saveTeams()
        }
        savePlayers()
    }

    func updatePlayerStats(playerId: String, gameStats: PlayerGameStats) async {
        guard let idx = players.firstIndex(where: { $0.id == playerId }) else { return }

        players[idx].stats.atBats += gameStats.atBats
        players[idx].stats.hits += gameStats.hits
        players[idx].stats.singles += gameStats.singles
        players[idx].stats.doubles += gameStats.doubles
        players[idx].stats.triples += gameStats.triples
        players[idx].stats.homeRuns += gameStats.homeRuns
        players[idx].stats.runs += gameStats.runs
        players[idx].stats.rbi += gameStats.rbi
        players[idx].stats.strikeouts += gameStats.strikeouts
        players[idx].stats.walks += gameStats.walks
        players[idx].stats.gamesPlayed += 1

        savePlayers()
    }

    // MARK: - Team Operations

    func addTeam(name: String) async {
        let team = Team(name: name)
        teams.append(team)
        teams.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        saveTeams()
    }

    func updateTeam(_ team: Team) async {
        if let idx = teams.firstIndex(where: { $0.id == team.id }) {
            teams[idx] = team
        }
        saveTeams()
    }

    func deleteTeam(_ team: Team) async {
        // Unassign all players from this team
        for i in players.indices where players[i].teamId == team.id {
            players[i].teamId = nil
        }
        teams.removeAll { $0.id == team.id }
        savePlayers()
        saveTeams()
    }

    func assignPlayerToTeam(playerId: String, teamId: String?) async {
        guard let playerIdx = players.firstIndex(where: { $0.id == playerId }) else { return }

        // Remove from old team
        if let oldTeamId = players[playerIdx].teamId,
           let oldIdx = teams.firstIndex(where: { $0.id == oldTeamId }) {
            teams[oldIdx].playerIds.removeAll { $0 == playerId }
        }

        // Update player
        players[playerIdx].teamId = teamId

        // Add to new team
        if let teamId,
           let newIdx = teams.firstIndex(where: { $0.id == teamId }) {
            if !teams[newIdx].playerIds.contains(playerId) {
                teams[newIdx].playerIds.append(playerId)
            }
        }

        savePlayers()
        saveTeams()
    }

    // MARK: - Tournament Operations

    func createTournament(name: String, teamIds: [String]) async {
        var newTournament = Tournament(name: name, teamIds: teamIds)
        newTournament.bracket = generateBracket(teamIds: teamIds)
        newTournament.status = .inProgress
        tournament = newTournament
        saveTournament()
    }

    func updateTournament(_ tournament: Tournament) async {
        self.tournament = tournament
        saveTournament()
    }

    func deleteTournament() async {
        tournament = nil
        let url = Self.documentsURL.appendingPathComponent("tournament.json")
        try? FileManager.default.removeItem(at: url)
    }

    func recordGameResult(
        roundIndex: Int,
        matchupIndex: Int,
        gameIndex: Int,
        team1Score: Int,
        team2Score: Int,
        playerStats: [PlayerGameStats]
    ) async {
        guard var tournament else { return }
        guard roundIndex < tournament.bracket.count,
              matchupIndex < tournament.bracket[roundIndex].matchups.count
        else { return }

        var matchup = tournament.bracket[roundIndex].matchups[matchupIndex]

        // Update or create the game
        if gameIndex < matchup.games.count {
            matchup.games[gameIndex].team1Score = team1Score
            matchup.games[gameIndex].team2Score = team2Score
            matchup.games[gameIndex].playerGameStats = playerStats
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
            if let team1Id = matchup.team1Id {
                await incrementTeamWins(teamId: team1Id)
            }
            if let team2Id = matchup.team2Id {
                await incrementTeamLosses(teamId: team2Id)
            }
        } else if matchup.team2Wins >= 2 {
            matchup.winnerId = matchup.team2Id
            matchup.status = .completed
            if let team2Id = matchup.team2Id {
                await incrementTeamWins(teamId: team2Id)
            }
            if let team1Id = matchup.team1Id {
                await incrementTeamLosses(teamId: team1Id)
            }
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

    // MARK: - Helpers

    private func incrementTeamWins(teamId: String) async {
        guard let idx = teams.firstIndex(where: { $0.id == teamId }) else { return }
        teams[idx].wins += 1
        saveTeams()
    }

    private func incrementTeamLosses(teamId: String) async {
        guard let idx = teams.firstIndex(where: { $0.id == teamId }) else { return }
        teams[idx].losses += 1
        saveTeams()
    }

    private func generateBracket(teamIds: [String]) -> [BracketRound] {
        let count = teamIds.count
        var size = 1
        while size < count { size *= 2 }

        var paddedTeams: [String?] = teamIds.map { $0 }
        while paddedTeams.count < size {
            paddedTeams.append(nil)
        }

        let seeded = seedBracket(paddedTeams)

        var rounds: [BracketRound] = []
        var currentMatchups: [Matchup] = []

        for i in stride(from: 0, to: seeded.count, by: 2) {
            var matchup = Matchup(team1Id: seeded[i], team2Id: seeded[i + 1])
            if matchup.team1Id != nil && matchup.team2Id == nil {
                matchup.winnerId = matchup.team1Id
                matchup.status = .completed
            } else if matchup.team1Id == nil && matchup.team2Id != nil {
                matchup.winnerId = matchup.team2Id
                matchup.status = .completed
            }
            currentMatchups.append(matchup)
        }

        let roundNames = generateRoundNames(totalRounds: Int(log2(Double(size))))
        rounds.append(BracketRound(
            roundNumber: 1,
            roundName: roundNames[0],
            matchups: currentMatchups
        ))

        var numMatchups = currentMatchups.count / 2
        var roundNum = 2
        while numMatchups >= 1 {
            var nextMatchups: [Matchup] = []
            for i in 0..<numMatchups {
                let prevIdx1 = i * 2
                let prevIdx2 = i * 2 + 1
                let team1 = prevIdx1 < currentMatchups.count ? currentMatchups[prevIdx1].winnerId : nil
                let team2 = prevIdx2 < currentMatchups.count ? currentMatchups[prevIdx2].winnerId : nil
                nextMatchups.append(Matchup(team1Id: team1, team2Id: team2))
            }

            let nameIndex = min(roundNum - 1, roundNames.count - 1)
            rounds.append(BracketRound(
                roundNumber: roundNum,
                roundName: roundNames[nameIndex],
                matchups: nextMatchups
            ))

            currentMatchups = nextMatchups
            numMatchups /= 2
            roundNum += 1
        }

        return rounds
    }

    private func seedBracket(_ teams: [String?]) -> [String?] {
        let count = teams.count
        if count <= 1 { return teams }

        var order: [Int] = [0]
        var step = 1
        while step < count {
            var newOrder: [Int] = []
            for idx in order {
                newOrder.append(idx)
                newOrder.append(step * 2 - 1 - idx)
            }
            order = newOrder
            step *= 2
        }

        return order.map { idx in
            idx < teams.count ? teams[idx] : nil
        }
    }

    private func generateRoundNames(totalRounds: Int) -> [String] {
        var names: [String] = []
        for i in 0..<totalRounds {
            let remaining = totalRounds - i
            switch remaining {
            case 1: names.append("Finals")
            case 2: names.append("Semifinals")
            case 3: names.append("Quarterfinals")
            default: names.append("Round \(i + 1)")
            }
        }
        return names
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
