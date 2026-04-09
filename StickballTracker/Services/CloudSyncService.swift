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

    func createTournament(name: String, tierConfigs: [TierConfig]) async {
        let allTeamIds = tierConfigs.flatMap { $0.teamIds }
        var tournament = Tournament(name: name, teamIds: Array(Set(allTeamIds)))

        for config in tierConfigs {
            let tier = generateDoubleEliminationTier(config: config)
            tournament.tiers.append(tier)
        }

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
        tierIndex: Int,
        gameId: String,
        team1Score: Int,
        team2Score: Int,
        field: String?,
        gameDate: Date?,
        playerStats: [PlayerGameStats]
    ) async {
        guard var tournament else { return }
        guard tierIndex < tournament.tiers.count else { return }

        guard let gameIdx = tournament.tiers[tierIndex].games.firstIndex(where: { $0.id == gameId }) else { return }

        var game = tournament.tiers[tierIndex].games[gameIdx]
        game.team1Score = team1Score
        game.team2Score = team2Score
        game.playerGameStats = playerStats
        game.field = field
        game.scheduledTime = gameDate
        game.status = .completed
        game.completedAt = Date()

        if team1Score > team2Score {
            game.winnerId = game.team1Id
            game.loserId = game.team2Id
        } else if team2Score > team1Score {
            game.winnerId = game.team2Id
            game.loserId = game.team1Id
        }

        tournament.tiers[tierIndex].games[gameIdx] = game

        // Route winner to next game
        if let winnerId = game.winnerId, let link = game.feedsWinnerTo {
            if let destIdx = tournament.tiers[tierIndex].games.firstIndex(where: { $0.id == link.gameId }) {
                switch link.slot {
                case .team1:
                    tournament.tiers[tierIndex].games[destIdx].team1Id = winnerId
                case .team2:
                    tournament.tiers[tierIndex].games[destIdx].team2Id = winnerId
                }
            }
        }

        // Route loser to losers bracket (or eliminated if no link)
        if let loserId = game.loserId, let link = game.feedsLoserTo {
            if let destIdx = tournament.tiers[tierIndex].games.firstIndex(where: { $0.id == link.gameId }) {
                switch link.slot {
                case .team1:
                    tournament.tiers[tierIndex].games[destIdx].team1Id = loserId
                case .team2:
                    tournament.tiers[tierIndex].games[destIdx].team2Id = loserId
                }
            }
        }

        // Championship special: if LB champion beats WB champion, activate if-necessary game
        if game.bracketSide == .championship,
           let winnerId = game.winnerId,
           let ifNecId = tournament.tiers[tierIndex].ifNecessaryGameId {
            // The WB champion is team1 in championship game; if LB champion (team2) wins, play if-necessary
            if winnerId == game.team2Id {
                if let ifNecIdx = tournament.tiers[tierIndex].games.firstIndex(where: { $0.id == ifNecId }) {
                    tournament.tiers[tierIndex].games[ifNecIdx].team1Id = game.team1Id
                    tournament.tiers[tierIndex].games[ifNecIdx].team2Id = game.team2Id
                    tournament.tiers[tierIndex].games[ifNecIdx].status = .pending
                }
            } else {
                // WB champion won — tier is done, no if-necessary needed
            }
        }

        // Update tier status
        let tier = tournament.tiers[tierIndex]
        let allGamesResolved = tier.games.allSatisfy { g in
            g.status == .completed ||
            (g.team1Id == nil && g.team2Id == nil) ||
            (g.bracketSide == .ifNecessary && !isIfNecessaryNeeded(tier: tier))
        }
        if allGamesResolved {
            tournament.tiers[tierIndex].status = .completed
            tournament.tiers[tierIndex].advancingTeamIds = computeAdvancingTeams(tier: tier)
        } else {
            tournament.tiers[tierIndex].status = .inProgress
        }

        // Check overall tournament completion
        if tournament.tiers.allSatisfy({ $0.status == .completed }) {
            tournament.status = .completed
        }

        // Accumulate player career stats
        for stats in playerStats {
            await updatePlayerStats(playerId: stats.playerId, gameStats: stats)
        }

        await updateTournament(tournament)
    }

    private func isIfNecessaryNeeded(tier: TournamentTier) -> Bool {
        guard let champId = tier.championshipGameId,
              let champGame = tier.game(byId: champId) else { return false }
        // If championship completed and LB champion (team2) won, if-necessary is needed
        return champGame.status == .completed && champGame.winnerId == champGame.team2Id
    }

    private func computeAdvancingTeams(tier: TournamentTier) -> [String] {
        // The tier champion + runners-up advance
        // For now, return teams that won their last game (championship/if-necessary winner + semifinal losers who placed well)
        // This will be manually managed by the user via advancingTeamIds
        return tier.advancingTeamIds
    }

    // MARK: - Double Elimination Bracket Generation

    struct TierConfig {
        var tierNumber: Int          // 1, 2, or 3
        var tierName: String         // "Round 1", "Round 2", "Championship"
        var dayLabel: String         // "Friday", "Saturday", "Sunday"
        var date: Date?
        var teamIds: [String]        // Seeded order
    }

    private func generateDoubleEliminationTier(config: TierConfig) -> TournamentTier {
        let teamCount = config.teamIds.count
        var tier = TournamentTier(
            tierNumber: config.tierNumber,
            tierName: config.tierName,
            dayLabel: config.dayLabel,
            date: config.date,
            teamIds: config.teamIds
        )

        var games: [TournamentGame] = []
        var gameNumber = 1

        // --- Winners Bracket ---
        let wbSize = nextPowerOf2(teamCount)
        let firstRoundGames = wbSize / 2

        // Build WB rounds
        var wbRounds: [[String]] = []  // Each round is an array of game IDs
        var lbRounds: [[String]] = []

        // WB Round 1 — some may be byes
        var wbR1GameIds: [String] = []
        // WB Round 1 game generation

        for i in 0..<firstRoundGames {
            let seed1 = i
            let seed2 = wbSize - 1 - i
            let team1Id = seed1 < teamCount ? config.teamIds[seed1] : nil
            let team2Id = seed2 < teamCount ? config.teamIds[seed2] : nil

            if team1Id != nil && team2Id != nil {
                // Real game
                let game = TournamentGame(gameNumber: gameNumber, bracketSide: .winners, team1Id: team1Id, team2Id: team2Id)
                gameNumber += 1
                wbR1GameIds.append(game.id)
                games.append(game)
            } else if team1Id != nil {
                // Bye — team1 auto-advances, no game needed
                // We'll handle byes by directly placing teams in next round
                // Use a placeholder game marked as completed
                var game = TournamentGame(gameNumber: gameNumber, bracketSide: .winners, team1Id: team1Id, team2Id: nil)
                game.winnerId = team1Id
                game.status = .completed
                gameNumber += 1
                wbR1GameIds.append(game.id)
                games.append(game)
            }
        }
        if !wbR1GameIds.isEmpty {
            wbRounds.append(wbR1GameIds)
        }

        // Subsequent WB rounds
        var prevRoundCount = firstRoundGames
        while prevRoundCount > 1 {
            let thisRoundCount = prevRoundCount / 2
            var roundGameIds: [String] = []

            for _ in 0..<thisRoundCount {
                let game = TournamentGame(gameNumber: gameNumber, bracketSide: .winners)
                gameNumber += 1
                roundGameIds.append(game.id)
                games.append(game)
            }
            wbRounds.append(roundGameIds)
            prevRoundCount = thisRoundCount
        }

        // --- Losers Bracket ---
        // LB receives losers from WB. Structure depends on team count.
        // For N teams in WB with R rounds:
        //   LB has (R-1)*2 rounds approximately
        //   Odd LB rounds: receive WB dropdowns
        //   Even LB rounds: internal matchups

        let wbRoundCount = wbRounds.count
        if wbRoundCount > 1 {
            // LB round 1: losers from WB round 1 play each other
            let wb1Losers = wbR1GameIds.count
            let lbR1Games = wb1Losers / 2
            var lbR1Ids: [String] = []
            for _ in 0..<max(lbR1Games, 1) {
                let game = TournamentGame(gameNumber: gameNumber, bracketSide: .losers)
                gameNumber += 1
                lbR1Ids.append(game.id)
                games.append(game)
            }
            if !lbR1Ids.isEmpty {
                lbRounds.append(lbR1Ids)
            }

            // LB subsequent rounds: alternate between receiving WB dropdowns and internal matchups
            var lbTeamCount = lbR1Ids.count  // number of "slots" coming out of LB round 1
            for wbRound in 1..<wbRoundCount {
                // Dropdown round: WB round losers drop into LB
                let wbDropdowns = wbRounds[wbRound].count
                let dropdownGames = max(lbTeamCount, wbDropdowns)
                var dropIds: [String] = []
                for _ in 0..<dropdownGames {
                    var game = TournamentGame(gameNumber: gameNumber, bracketSide: .losers)
                    gameNumber += 1
                    dropIds.append(game.id)
                    games.append(game)
                }
                lbRounds.append(dropIds)
                lbTeamCount = dropIds.count

                // Internal LB round (if more than 1 team remaining)
                if lbTeamCount > 1 {
                    let internalGames = lbTeamCount / 2
                    var intIds: [String] = []
                    for _ in 0..<internalGames {
                        var game = TournamentGame(gameNumber: gameNumber, bracketSide: .losers)
                        gameNumber += 1
                        intIds.append(game.id)
                        games.append(game)
                    }
                    lbRounds.append(intIds)
                    lbTeamCount = internalGames
                }
            }
        }

        // --- Championship Game ---
        let champGame = TournamentGame(gameNumber: gameNumber, bracketSide: .championship)
        gameNumber += 1
        let champId = champGame.id
        games.append(champGame)

        // --- If Necessary Game ---
        let ifNecGame = TournamentGame(gameNumber: gameNumber, bracketSide: .ifNecessary)
        let ifNecId = ifNecGame.id
        games.append(ifNecGame)

        // --- Wire up feedsWinnerTo / feedsLoserTo links ---
        // WB: winners advance within WB, losers drop to LB
        for roundIdx in 0..<wbRounds.count {
            let roundIds = wbRounds[roundIdx]
            for (i, gId) in roundIds.enumerated() {
                guard let gIdx = games.firstIndex(where: { $0.id == gId }) else { continue }

                // Winner goes to next WB round
                if roundIdx + 1 < wbRounds.count {
                    let nextRound = wbRounds[roundIdx + 1]
                    let nextSlotIdx = i / 2
                    if nextSlotIdx < nextRound.count {
                        let slot: TeamSlot = (i % 2 == 0) ? .team1 : .team2
                        games[gIdx].feedsWinnerTo = GameLink(gameId: nextRound[nextSlotIdx], slot: slot)
                    }
                } else {
                    // WB final winner goes to championship as team1
                    games[gIdx].feedsWinnerTo = GameLink(gameId: champId, slot: .team1)
                }

                // Loser drops to LB
                if !lbRounds.isEmpty {
                    // Map WB round losers to appropriate LB round
                    let lbTargetRound: Int
                    if roundIdx == 0 {
                        lbTargetRound = 0
                    } else {
                        // WB round R losers go to LB dropdown round
                        lbTargetRound = min(roundIdx * 2 - 1, lbRounds.count - 1)
                    }

                    if lbTargetRound < lbRounds.count {
                        let lbRound = lbRounds[lbTargetRound]
                        let lbSlotIdx = i / 2
                        if lbSlotIdx < lbRound.count {
                            let slot: TeamSlot
                            if roundIdx == 0 {
                                slot = (i % 2 == 0) ? .team1 : .team2
                            } else {
                                slot = .team2  // WB dropdowns always go to team2 slot
                            }
                            games[gIdx].feedsLoserTo = GameLink(gameId: lbRound[lbSlotIdx], slot: slot)
                        }
                    }
                }
            }
        }

        // LB: winners advance within LB, losers eliminated
        for roundIdx in 0..<lbRounds.count {
            let roundIds = lbRounds[roundIdx]
            for (i, gId) in roundIds.enumerated() {
                guard let gIdx = games.firstIndex(where: { $0.id == gId }) else { continue }

                if roundIdx + 1 < lbRounds.count {
                    let nextRound = lbRounds[roundIdx + 1]
                    let nextSlotIdx = i / 2
                    if nextSlotIdx < nextRound.count {
                        let slot: TeamSlot = (i % 2 == 0) ? .team1 : .team2
                        games[gIdx].feedsWinnerTo = GameLink(gameId: nextRound[nextSlotIdx], slot: slot)
                    }
                } else {
                    // LB final winner goes to championship as team2
                    games[gIdx].feedsWinnerTo = GameLink(gameId: champId, slot: .team2)
                }
                // LB losers: feedsLoserTo = nil (eliminated)
            }
        }

        // Championship winner: if WB champ wins, they're the tier champion
        // If LB champ wins, if-necessary is activated (wired in recordGameResult)
        if let champIdx = games.firstIndex(where: { $0.id == champId }) {
            games[champIdx].feedsWinnerTo = nil // handled specially
        }

        tier.games = games
        tier.winnersBracketGameIds = wbRounds
        tier.losersBracketGameIds = lbRounds
        tier.championshipGameId = champId
        tier.ifNecessaryGameId = ifNecId
        tier.status = .upcoming

        return tier
    }

    private func nextPowerOf2(_ n: Int) -> Int {
        var v = 1
        while v < n { v *= 2 }
        return v
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
