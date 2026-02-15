import Foundation
import FirebaseFirestore
import Combine

/// Cloud sync service using Firebase Firestore for real-time multi-user synchronization.
/// Every mutation writes to Firestore; snapshot listeners push changes to all connected devices.
@MainActor
class CloudSyncService: ObservableObject {
    @Published var players: [Player] = []
    @Published var teams: [Team] = []
    @Published var tournament: Tournament?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []

    init() {
        attachListeners()
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
        player.stats.atBats += gameStats.atBats
        player.stats.hits += gameStats.hits
        player.stats.singles += gameStats.singles
        player.stats.doubles += gameStats.doubles
        player.stats.triples += gameStats.triples
        player.stats.homeRuns += gameStats.homeRuns
        player.stats.runs += gameStats.runs
        player.stats.rbi += gameStats.rbi
        player.stats.strikeouts += gameStats.strikeouts
        player.stats.walks += gameStats.walks
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

    func createTournament(name: String, teamIds: [String]) async {
        var tournament = Tournament(name: name, teamIds: teamIds)
        tournament.bracket = generateBracket(teamIds: teamIds)
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
            if let id = matchup.team1Id { await incrementTeamWins(teamId: id) }
            if let id = matchup.team2Id { await incrementTeamLosses(teamId: id) }
        } else if matchup.team2Wins >= 2 {
            matchup.winnerId = matchup.team2Id
            matchup.status = .completed
            if let id = matchup.team2Id { await incrementTeamWins(teamId: id) }
            if let id = matchup.team1Id { await incrementTeamLosses(teamId: id) }
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
        guard var team = teams.first(where: { $0.id == teamId }) else { return }
        team.wins += 1
        await updateTeam(team)
    }

    private func incrementTeamLosses(teamId: String) async {
        guard var team = teams.first(where: { $0.id == teamId }) else { return }
        team.losses += 1
        await updateTeam(team)
    }

    private func generateBracket(teamIds: [String]) -> [BracketRound] {
        let count = teamIds.count
        var size = 1
        while size < count { size *= 2 }

        var paddedTeams: [String?] = teamIds.map { $0 }
        while paddedTeams.count < size { paddedTeams.append(nil) }

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
        rounds.append(BracketRound(roundNumber: 1, roundName: roundNames[0], matchups: currentMatchups))

        var numMatchups = currentMatchups.count / 2
        var roundNum = 2
        while numMatchups >= 1 {
            var nextMatchups: [Matchup] = []
            for i in 0..<numMatchups {
                let team1 = (i * 2) < currentMatchups.count ? currentMatchups[i * 2].winnerId : nil
                let team2 = (i * 2 + 1) < currentMatchups.count ? currentMatchups[i * 2 + 1].winnerId : nil
                nextMatchups.append(Matchup(team1Id: team1, team2Id: team2))
            }
            let nameIndex = min(roundNum - 1, roundNames.count - 1)
            rounds.append(BracketRound(roundNumber: roundNum, roundName: roundNames[nameIndex], matchups: nextMatchups))
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
        return order.map { idx in idx < teams.count ? teams[idx] : nil }
    }

    private func generateRoundNames(totalRounds: Int) -> [String] {
        (0..<totalRounds).map { i in
            switch totalRounds - i {
            case 1: return "Finals"
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
