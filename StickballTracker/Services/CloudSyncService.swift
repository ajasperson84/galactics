import Foundation
import FirebaseFirestore
import Combine

// MARK: - Access Level

enum AccessLevel: Int {
    case viewOnly = 0
    case scorekeeper = 1
    case admin = 2
}

/// Cloud sync service using Firebase Firestore for real-time multi-user synchronization.
/// Also persists data locally as JSON so it survives app restarts even without connectivity.
@MainActor
class CloudSyncService: ObservableObject {
    @Published var players: [Player] = []
    @Published var teams: [Team] = []
    @Published var tournament: Tournament?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var accessLevel: AccessLevel = .viewOnly
    /// True once the Firestore tournament listener has returned at least one snapshot.
    /// Used by views to distinguish "still loading" from "confirmed no tournament".
    @Published var hasLoadedTournament: Bool = false

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
            hasLoadedTournament = true
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
                        self.errorMessage = "Tourney sync error: \(error.localizedDescription)"
                        // Mark as loaded so the UI can stop showing a spinner and
                        // surface whatever cached state we have (or empty state).
                        self.hasLoadedTournament = true
                        return
                    }
                    guard let snapshot else {
                        self.hasLoadedTournament = true
                        return
                    }
                    if let doc = snapshot.documents.first {
                        if let decoded = try? doc.data(as: Tournament.self) {
                            self.tournament = decoded
                            self.saveTournament()
                        } else {
                            // Decoding failed — keep any existing tournament (from disk
                            // or a prior successful snapshot) rather than nulling it out.
                            self.errorMessage = "Failed to decode tourney data."
                        }
                    } else {
                        // Confirmed: no tournament exists in Firestore.
                        self.tournament = nil
                        self.saveTournament()
                    }
                    self.hasLoadedTournament = true
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

    func addTeam(name: String, iconName: String? = nil) async {
        let team = Team(name: name, iconName: iconName)
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

    // MARK: - Seed Tournament Teams

    func seedTournamentTeams() async {
        // Team name → icon asset name (matches TeamIconView.teamLogos)
        let allTeams: [(name: String, icon: String)] = [
            // Day 1 teams (9)
            ("Banditos",             "Banditos"),
            ("No Mames Wey Jovenes", "NMW_JOVENES"),
            ("Mothership JV Reds",   "BJVRED"),
            ("Mothership JV Blacks", "B"),
            ("Tinseltown JV",        "TTFBJV"),
            ("Rose City JV",         "RCJV"),
            ("D$$",                  "DSS"),
            ("Steel City",           "Steel-City"),
            ("Gold Coast",           "Gold-Coast"),
            // Day 2 teams (5)
            ("Mothership Champs",    "B_GOLD"),
            ("Tinseltown Champs",    "TTFB_GOLD"),
            ("Rose City Champs",     "Rose-City_GOLD"),
            ("Jet City Champs",      "Jet-City_GOLD"),
            ("No Mames Wey Viejos",  "NMW_VIEJOS"),
        ]
        let existingNames = Set(teams.map { $0.name })
        for team in allTeams where !existingNames.contains(team.name) {
            await addTeam(name: team.name, iconName: team.icon)
        }
    }

    func seedTournamentPlayers() async {
        let existingNames = Set(players.map { $0.name })

        let teamRosters: [(teamName: String, players: [String])] = [
            ("Banditos",             ["The Rabbit", "Bandit Rick", "Wildcat", "Bandit Mitch", "Bandito Mayor"]),
            ("No Mames Wey Jovenes", ["Flacco", "The Future", "Chino", "Rookie Alex"]),
            ("Tinseltown JV",        ["Cuidado", "Dublé", "$alary", "Cojones", "Flashdance"]),
            ("D$$",                  ["Lil Diamond", "Cap'n", "Katfish", "Rooster", "Hell Yeah Why Not?"]),
            ("Steel City",           ["Solo Shot", "Clown Car", "Madre", "MidBen", "Mothman"]),
            ("Gold Coast",           ["The Mechanic", "Cocaine Greg", "The Big Puna", "The Rookie", "Shroomin Mo"]),
            ("Mothership Champs",    ["Soy Peligroso", "Jeffery Bomber", "Deep Space", "ODC", "Plough Jones"]),
            ("Jet City Champs",      ["Daisy Cutter", "Well Fed Man", "Dirt Bag", "AAA", "Deadliest Catch"]),
            ("Tinseltown Champs",    ["The Deal", "Dong Robber", "Lunch Money", "Candyman"]),
            ("No Mames Wey Viejos",  ["El Toro", "Fuck Mañana", "Rookie Ulee", "Pelone"]),
            ("Rose City Champs",     ["Big Trip", "Trees", "Almost Famous"]),
            ("Rose City JV",         ["Honey Hamms", "Serial Killer", "The Wizard", "Holifield", "Cricket", "ShamWow"]),
        ]

        for roster in teamRosters {
            guard let team = teams.first(where: { $0.name == roster.teamName }) else { continue }
            for playerName in roster.players where !existingNames.contains(playerName) {
                await addPlayer(name: playerName, teamId: team.id)
            }
        }

        // Mothership JV pool — free agents until drafted
        let freeAgents = ["The Surgeon", "8 Ball", "Stanklove", "Monkdank", "The Shepherd", "Long Balls", "Beverly Hills Cact", "Windows 95"]
        for playerName in freeAgents where !existingNames.contains(playerName) {
            await addPlayer(name: playerName, teamId: nil)
        }
    }

    // MARK: - Tournament Operations

    struct TierConfig {
        var tierNumber: Int          // 1, 2, or 3
        var tierName: String         // "Round 1", "Round 2", "Championship"
        var dayLabel: String         // "Friday", "Saturday", "Sunday"
        var date: Date?
        var teamIds: [String]        // Seeded order
    }

    func createTournament(name: String, tierConfigs: [TierConfig]) async {
        let allTeamIds = tierConfigs.flatMap { $0.teamIds }
        var tournament = Tournament(name: name, teamIds: Array(Set(allTeamIds)))

        for config in tierConfigs {
            let tier: TournamentTier
            switch config.tierNumber {
            case 1: tier = generateDay1Bracket(config: config)
            case 2: tier = generateDay2Bracket(config: config)
            case 3: tier = generateDay3Bracket(config: config)
            default: tier = generateDay1Bracket(config: config)
            }
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

    // MARK: - Team Assignment

    func assignTeamToGameSlot(tierIndex: Int, gameId: String, slot: TeamSlot, teamId: String) async {
        guard var tournament else { return }
        guard tierIndex < tournament.tiers.count else { return }
        guard let gameIdx = tournament.tiers[tierIndex].games.firstIndex(where: { $0.id == gameId }) else { return }

        switch slot {
        case .team1:
            tournament.tiers[tierIndex].games[gameIdx].team1Id = teamId
        case .team2:
            tournament.tiers[tierIndex].games[gameIdx].team2Id = teamId
        }

        self.tournament = tournament
        await updateTournament(tournament)
    }

    /// Teams that lost a game with no auto-routing and aren't placed in any pending game
    func unplacedLosers(tierIndex: Int) -> [String] {
        guard let tournament, tierIndex < tournament.tiers.count else { return [] }
        let tier = tournament.tiers[tierIndex]

        let placedInPending = Set(
            tier.games
                .filter { $0.status != .completed }
                .flatMap { [$0.team1Id, $0.team2Id] }
                .compactMap { $0 }
        )

        var unplaced: [String] = []
        for game in tier.games where game.status == .completed {
            guard let loserId = game.loserId else { continue }
            if game.feedsLoserTo == nil && !placedInPending.contains(loserId) {
                unplaced.append(loserId)
            }
        }
        return unplaced
    }

    /// Teams in this tier not assigned to any game yet (for initial WB R1 setup)
    func unassignedTierTeams(tierIndex: Int) -> [String] {
        guard let tournament, tierIndex < tournament.tiers.count else { return [] }
        let tier = tournament.tiers[tierIndex]

        let assignedTeamIds = Set(
            tier.games.flatMap { [$0.team1Id, $0.team2Id] }.compactMap { $0 }
        )

        return tier.teamIds.filter { !assignedTeamIds.contains($0) }
    }

    /// Check if a game slot has an automatic feed from another game's winner/loser routing
    func slotHasAutoFeed(tierIndex: Int, gameId: String, slot: TeamSlot) -> Bool {
        guard let tournament, tierIndex < tournament.tiers.count else { return false }
        let tier = tournament.tiers[tierIndex]
        for game in tier.games {
            if let link = game.feedsWinnerTo, link.gameId == gameId, link.slot == slot { return true }
            if let link = game.feedsLoserTo, link.gameId == gameId, link.slot == slot { return true }
        }
        return false
    }

    // MARK: - Inning Tracking

    func updateGameInning(tierIndex: Int, gameId: String, inning: Int?) async {
        guard var tournament else { return }
        guard tierIndex < tournament.tiers.count else { return }
        guard let gameIdx = tournament.tiers[tierIndex].games.firstIndex(where: { $0.id == gameId }) else { return }
        tournament.tiers[tierIndex].games[gameIdx].currentInning = inning
        if inning != nil && tournament.tiers[tierIndex].games[gameIdx].status == .pending {
            tournament.tiers[tierIndex].games[gameIdx].status = .inProgress
            tournament.tiers[tierIndex].status = .inProgress
        }
        self.tournament = tournament
        await updateTournament(tournament)
    }

    // MARK: - Live Score Update

    func updateGameScores(tierIndex: Int, gameId: String, team1Score: Int, team2Score: Int) async {
        guard var tournament else { return }
        guard tierIndex < tournament.tiers.count else { return }
        guard let gameIdx = tournament.tiers[tierIndex].games.firstIndex(where: { $0.id == gameId }) else { return }
        tournament.tiers[tierIndex].games[gameIdx].team1Score = team1Score
        tournament.tiers[tierIndex].games[gameIdx].team2Score = team2Score
        if tournament.tiers[tierIndex].games[gameIdx].status == .pending {
            tournament.tiers[tierIndex].games[gameIdx].status = .inProgress
            tournament.tiers[tierIndex].status = .inProgress
        }
        self.tournament = tournament
        await updateTournament(tournament)
    }

    // MARK: - Record Game Result

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
            }
        }

        // Update tier status
        let tier = tournament.tiers[tierIndex]
        let allGamesResolved = tier.games.allSatisfy { g in
            g.status == .completed ||
            (g.bracketSide == .ifNecessary && (tier.ifNecessaryGameId == nil || !isIfNecessaryNeeded(tier: tier)))
        }
        if allGamesResolved {
            tournament.tiers[tierIndex].status = .completed
            let advancing = computeAdvancingTeams(tier: tournament.tiers[tierIndex])
            tournament.tiers[tierIndex].advancingTeamIds = advancing

            // Advance teams to next tier
            let nextIdx = tierIndex + 1
            if nextIdx < tournament.tiers.count {
                for teamId in advancing {
                    if !tournament.tiers[nextIdx].teamIds.contains(teamId) {
                        tournament.tiers[nextIdx].teamIds.append(teamId)
                    }
                }
            }
        } else {
            tournament.tiers[tierIndex].status = .inProgress
        }

        // Check overall tournament completion
        if tournament.tiers.allSatisfy({ $0.status == .completed }) {
            tournament.status = .completed
        }

        self.tournament = tournament

        // Accumulate player career stats
        for stats in playerStats {
            await updatePlayerStats(playerId: stats.playerId, gameStats: stats)
        }

        await updateTournament(tournament)
    }

    private func isIfNecessaryNeeded(tier: TournamentTier) -> Bool {
        guard let champId = tier.championshipGameId,
              let champGame = tier.game(byId: champId) else { return false }
        return champGame.status == .completed && champGame.winnerId == champGame.team2Id
    }

    private func computeAdvancingTeams(tier: TournamentTier) -> [String] {
        switch tier.tierNumber {
        case 1:
            // Day 1: 2 WB semi winners + 1 LB final winner = 3
            var advancing: [String] = []
            // WB semi winners (last WB round)
            if let wbSF = tier.winnersBracketRounds.last {
                for gId in wbSF.gameIds {
                    if let g = tier.game(byId: gId), let w = g.winnerId {
                        advancing.append(w)
                    }
                }
            }
            // LB final winner (last LB round)
            if let lbFinal = tier.losersBracketRounds.last {
                for gId in lbFinal.gameIds {
                    if let g = tier.game(byId: gId), let w = g.winnerId {
                        advancing.append(w)
                    }
                }
            }
            return advancing

        case 2:
            // Day 2: 2 WB semi winners + 2 LB final round winners = 4
            var advancing: [String] = []
            if let wbSF = tier.winnersBracketRounds.last {
                for gId in wbSF.gameIds {
                    if let g = tier.game(byId: gId), let w = g.winnerId { advancing.append(w) }
                }
            }
            if let lbLast = tier.losersBracketRounds.last {
                for gId in lbLast.gameIds {
                    if let g = tier.game(byId: gId), let w = g.winnerId { advancing.append(w) }
                }
            }
            return advancing

        case 3:
            // Day 3: Tournament champion (if-necessary winner or championship winner)
            if let ifNecId = tier.ifNecessaryGameId,
               let ifNecGame = tier.game(byId: ifNecId),
               ifNecGame.status == .completed,
               let w = ifNecGame.winnerId {
                return [w]
            }
            if let champId = tier.championshipGameId,
               let champGame = tier.game(byId: champId),
               let w = champGame.winnerId {
                return [w]
            }
            return []

        default:
            return tier.advancingTeamIds
        }
    }

    // MARK: - Time Helper

    private func gameTime(year: Int = 2026, month: Int = 4, day: Int, hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: - Day 1 Bracket (9 teams, 13 games)
    //
    // WB R1: G1 (play-in: Banditos vs No Mamas), G2, G3, G4, G5 (G1W + manual)
    // WB SF: G9 (G2W vs G3W), G10 (G4W vs G5W)
    // LB R1: G6 (G1L + manual), G7 (2 manual losers)
    // LB R2: G8 (G6W + manual bye loser)
    // LB R3: G11 (G7W vs G10L), G12 (G8W vs G9L)
    // LB Final: G13 (G11W vs G12W)
    // Advances: G9W, G10W (WB semi winners) + G13W (LB final winner) = 3

    private func generateDay1Bracket(config: TierConfig) -> TournamentTier {
        var tier = TournamentTier(
            tierNumber: 1,
            tierName: config.tierName,
            dayLabel: config.dayLabel,
            date: config.date,
            teamIds: config.teamIds
        )

        // Find Banditos and No Mamas for auto-assignment to G1
        let banditosId = teams.first { $0.name == "Banditos" }?.id
        let noMamasId = teams.first { $0.name == "No Mames Wey Jovenes" }?.id

        // WB R1 (5 games)
        var g1 = TournamentGame(gameNumber: 1, bracketSide: .winners, team1Id: banditosId, team2Id: noMamasId)
        var g2 = TournamentGame(gameNumber: 2, bracketSide: .winners)
        var g3 = TournamentGame(gameNumber: 3, bracketSide: .winners)
        var g4 = TournamentGame(gameNumber: 4, bracketSide: .winners)
        var g5 = TournamentGame(gameNumber: 5, bracketSide: .winners) // G1W + manual team

        // LB R1 (2 games)
        var g6 = TournamentGame(gameNumber: 6, bracketSide: .losers)  // G1L + manual loser
        var g7 = TournamentGame(gameNumber: 7, bracketSide: .losers)  // 2 manual losers

        // LB R2 (1 game)
        var g8 = TournamentGame(gameNumber: 8, bracketSide: .losers)  // G6W + manual bye loser

        // WB SF (2 games)
        var g9 = TournamentGame(gameNumber: 9, bracketSide: .winners)  // G2W vs G3W
        var g10 = TournamentGame(gameNumber: 10, bracketSide: .winners) // G4W vs G5W

        // LB R3 (2 games — WB SF losers drop in)
        var g11 = TournamentGame(gameNumber: 11, bracketSide: .losers)  // G7W vs G10L
        var g12 = TournamentGame(gameNumber: 12, bracketSide: .losers)  // G8W vs G9L

        // LB Final (1 game)
        var g13 = TournamentGame(gameNumber: 13, bracketSide: .losers)  // G11W vs G12W

        // === Routing ===

        // WB R1 winners → WB SF
        g1.feedsWinnerTo = GameLink(gameId: g5.id, slot: .team1)   // G1W → G5 team1
        g2.feedsWinnerTo = GameLink(gameId: g9.id, slot: .team1)   // G2W → G9 team1
        g3.feedsWinnerTo = GameLink(gameId: g9.id, slot: .team2)   // G3W → G9 team2
        g4.feedsWinnerTo = GameLink(gameId: g10.id, slot: .team1)  // G4W → G10 team1
        g5.feedsWinnerTo = GameLink(gameId: g10.id, slot: .team2)  // G5W → G10 team2

        // WB R1 losers: G1L auto, rest manual
        g1.feedsLoserTo = GameLink(gameId: g6.id, slot: .team1)    // G1L → G6 team1 (auto)
        // G2, G3, G4, G5 losers: manual assignment to G6.team2, G7.team1, G7.team2, G8.team2

        // WB SF losers → LB R3
        g9.feedsLoserTo = GameLink(gameId: g12.id, slot: .team2)   // G9L → G12 team2
        g10.feedsLoserTo = GameLink(gameId: g11.id, slot: .team2)  // G10L → G11 team2

        // LB R1 winners
        g6.feedsWinnerTo = GameLink(gameId: g8.id, slot: .team1)   // G6W → G8 team1
        g7.feedsWinnerTo = GameLink(gameId: g11.id, slot: .team1)  // G7W → G11 team1

        // LB R2 winner
        g8.feedsWinnerTo = GameLink(gameId: g12.id, slot: .team1)  // G8W → G12 team1

        // LB R3 winners → LB Final
        g11.feedsWinnerTo = GameLink(gameId: g13.id, slot: .team1) // G11W → G13 team1
        g12.feedsWinnerTo = GameLink(gameId: g13.id, slot: .team2) // G12W → G13 team2

        // G13 winner advances, no further routing

        // === Scheduled Times (Day 1 = Friday April 24, G13 = Saturday April 25) ===
        g1.scheduledTime = gameTime(day: 24, hour: 9)           // 9:00 AM
        g2.scheduledTime = gameTime(day: 24, hour: 10, minute: 30)  // 10:30 AM
        g3.scheduledTime = gameTime(day: 24, hour: 10, minute: 30)  // 10:30 AM
        g4.scheduledTime = gameTime(day: 24, hour: 12)          // 12:00 PM
        g5.scheduledTime = gameTime(day: 24, hour: 12)          // 12:00 PM
        g6.scheduledTime = gameTime(day: 24, hour: 13, minute: 30)  // 1:30 PM
        g7.scheduledTime = gameTime(day: 24, hour: 13, minute: 30)  // 1:30 PM
        g8.scheduledTime = gameTime(day: 24, hour: 15)          // 3:00 PM
        g9.scheduledTime = gameTime(day: 24, hour: 15)          // 3:00 PM
        g10.scheduledTime = gameTime(day: 24, hour: 16, minute: 30) // 4:30 PM
        g11.scheduledTime = gameTime(day: 24, hour: 18)         // 6:00 PM
        g12.scheduledTime = gameTime(day: 24, hour: 18)         // 6:00 PM
        g13.scheduledTime = gameTime(day: 25, hour: 9)          // 9:00 AM SATURDAY

        // === Field Assignments ===
        // Games 1,2,5,6,9,10,11,13 → El Potrero
        // Games 3,4,7,8,12 → La Finca
        let potrero = StickballField.elPotrero.rawValue
        let finca = StickballField.laFinca.rawValue
        g1.field = potrero;  g2.field = potrero
        g3.field = finca;    g4.field = finca
        g5.field = potrero;  g6.field = potrero
        g7.field = finca;    g8.field = finca
        g9.field = potrero;  g10.field = potrero
        g11.field = potrero; g12.field = finca
        g13.field = potrero

        tier.games = [g1, g2, g3, g4, g5, g6, g7, g8, g9, g10, g11, g12, g13]

        tier.winnersBracketRounds = [
            BracketRoundGroup(name: "The Warm Up", gameIds: [g1.id]),
            BracketRoundGroup(name: "Round 1", gameIds: [g2.id, g3.id, g4.id, g5.id]),
            BracketRoundGroup(name: "Round 2", gameIds: [g9.id, g10.id])
        ]

        tier.losersBracketRounds = [
            BracketRoundGroup(name: "Purgatory", gameIds: [g6.id]),
            BracketRoundGroup(name: "Quarterfinals", gameIds: [g7.id, g8.id]),
            BracketRoundGroup(name: "Semifinals", gameIds: [g11.id, g12.id]),
            BracketRoundGroup(name: "Final", gameIds: [g13.id])
        ]

        tier.championshipGameId = nil
        tier.ifNecessaryGameId = nil
        tier.status = .upcoming

        return tier
    }

    // MARK: - Day 2 Bracket (8 teams, 10 games)
    //
    // 5 preset teams + 3 advancing from Day 1. All manually assigned to WB R1.
    // WB R1: G1, G2, G3, G4 (4 games, manual)
    // LB R1: G5, G6 (auto from WB R1 losers)
    // WB R2: G7, G8 (auto from WB R1 winners) — winners advance to Finals
    // LB R2: G9, G10 (LB R1 winners vs WB R2 losers) — winners advance to Finals
    // Advances: G7W, G8W (WB R2 winners) + G9W, G10W (LB R2 winners) = 4

    private func generateDay2Bracket(config: TierConfig) -> TournamentTier {
        var tier = TournamentTier(
            tierNumber: 2,
            tierName: config.tierName,
            dayLabel: config.dayLabel,
            date: config.date,
            teamIds: config.teamIds
        )

        // WB R1 (4 games, all manual assignment)
        var g1 = TournamentGame(gameNumber: 1, bracketSide: .winners)
        var g2 = TournamentGame(gameNumber: 2, bracketSide: .winners)
        var g3 = TournamentGame(gameNumber: 3, bracketSide: .winners)
        var g4 = TournamentGame(gameNumber: 4, bracketSide: .winners)

        // LB R1 (2 games, auto from WB R1 losers)
        var g5 = TournamentGame(gameNumber: 5, bracketSide: .losers)
        var g6 = TournamentGame(gameNumber: 6, bracketSide: .losers)

        // WB R2 (2 games, auto from WB R1 winners)
        var g7 = TournamentGame(gameNumber: 7, bracketSide: .winners)
        var g8 = TournamentGame(gameNumber: 8, bracketSide: .winners)

        // LB R2 (2 games, LB R1 winners vs WB R2 losers)
        var g9 = TournamentGame(gameNumber: 9, bracketSide: .losers)
        var g10 = TournamentGame(gameNumber: 10, bracketSide: .losers)

        // WB R1 winners → WB R2
        g1.feedsWinnerTo = GameLink(gameId: g7.id, slot: .team1)
        g2.feedsWinnerTo = GameLink(gameId: g7.id, slot: .team2)
        g3.feedsWinnerTo = GameLink(gameId: g8.id, slot: .team1)
        g4.feedsWinnerTo = GameLink(gameId: g8.id, slot: .team2)

        // WB R1 losers → LB R1 (all auto-routed)
        g1.feedsLoserTo = GameLink(gameId: g5.id, slot: .team1)
        g2.feedsLoserTo = GameLink(gameId: g5.id, slot: .team2)
        g3.feedsLoserTo = GameLink(gameId: g6.id, slot: .team1)
        g4.feedsLoserTo = GameLink(gameId: g6.id, slot: .team2)

        // LB R1 winners → LB R2 (crossover to prevent rematches)
        g5.feedsWinnerTo = GameLink(gameId: g9.id, slot: .team1)
        g6.feedsWinnerTo = GameLink(gameId: g10.id, slot: .team1)

        // WB R2 losers → LB R2 (crossover to prevent rematches)
        g7.feedsLoserTo = GameLink(gameId: g10.id, slot: .team2)
        g8.feedsLoserTo = GameLink(gameId: g9.id, slot: .team2)

        // WB R2 winners advance, LB R2 winners advance — no further routing

        // === Scheduled Times (Day 2 = Saturday April 25) ===
        g1.scheduledTime = gameTime(day: 25, hour: 10, minute: 30)  // 10:30 AM
        g2.scheduledTime = gameTime(day: 25, hour: 10, minute: 30)  // 10:30 AM
        g3.scheduledTime = gameTime(day: 25, hour: 12)          // 12:00 PM
        g4.scheduledTime = gameTime(day: 25, hour: 12)          // 12:00 PM
        g5.scheduledTime = gameTime(day: 25, hour: 13, minute: 30)  // 1:30 PM
        g6.scheduledTime = gameTime(day: 25, hour: 13, minute: 30)  // 1:30 PM
        g7.scheduledTime = gameTime(day: 25, hour: 15)          // 3:00 PM
        g8.scheduledTime = gameTime(day: 25, hour: 15)          // 3:00 PM
        g9.scheduledTime = gameTime(day: 25, hour: 16, minute: 30)  // 4:30 PM
        g10.scheduledTime = gameTime(day: 25, hour: 16, minute: 30) // 4:30 PM

        // === Field Assignments ===
        // Games 1,3,5,7,9 → Valle De Mystique
        // Games 2,4,6,8 → Lil Valle
        let valle = StickballField.valleDeMystique.rawValue
        let lil = StickballField.lilValle.rawValue
        g1.field = valle;  g2.field = lil
        g3.field = valle;  g4.field = lil
        g5.field = valle;  g6.field = lil
        g7.field = valle;  g8.field = lil
        g9.field = valle;  g10.field = lil

        tier.games = [g1, g2, g3, g4, g5, g6, g7, g8, g9, g10]

        tier.winnersBracketRounds = [
            BracketRoundGroup(name: "Round 1", gameIds: [g1.id, g2.id, g3.id, g4.id]),
            BracketRoundGroup(name: "Round 2", gameIds: [g7.id, g8.id])
        ]

        tier.losersBracketRounds = [
            BracketRoundGroup(name: "Round 1", gameIds: [g5.id, g6.id]),
            BracketRoundGroup(name: "Round 2", gameIds: [g9.id, g10.id])
        ]

        tier.championshipGameId = nil
        tier.ifNecessaryGameId = nil
        tier.status = .upcoming

        return tier
    }

    // MARK: - Day 3 Bracket (4 teams, up to 7 games)
    //
    // Standard 4-team double elimination with championship + if-necessary.
    // WB SF: G1, G2
    // WB Final: G3
    // LB R1: G4 (WB SF losers)
    // LB R2: G5 (G4W vs G3L)
    // Championship: G6 (G3W vs G5W)
    // If Necessary: G7 (if LB champion wins G6)

    private func generateDay3Bracket(config: TierConfig) -> TournamentTier {
        var tier = TournamentTier(
            tierNumber: 3,
            tierName: config.tierName,
            dayLabel: config.dayLabel,
            date: config.date,
            teamIds: config.teamIds
        )

        // WB SF (2 games, manual assignment)
        var g1 = TournamentGame(gameNumber: 1, bracketSide: .winners)
        var g2 = TournamentGame(gameNumber: 2, bracketSide: .winners)

        // WB Final
        var g3 = TournamentGame(gameNumber: 3, bracketSide: .winners)

        // LB R1
        var g4 = TournamentGame(gameNumber: 4, bracketSide: .losers)

        // LB R2 (LB Final)
        var g5 = TournamentGame(gameNumber: 5, bracketSide: .losers)

        // Championship
        var g6 = TournamentGame(gameNumber: 6, bracketSide: .championship)

        // If Necessary
        var g7 = TournamentGame(gameNumber: 7, bracketSide: .ifNecessary)

        // WB SF
        g1.feedsWinnerTo = GameLink(gameId: g3.id, slot: .team1)
        g1.feedsLoserTo = GameLink(gameId: g4.id, slot: .team1)

        g2.feedsWinnerTo = GameLink(gameId: g3.id, slot: .team2)
        g2.feedsLoserTo = GameLink(gameId: g4.id, slot: .team2)

        // WB Final
        g3.feedsWinnerTo = GameLink(gameId: g6.id, slot: .team1)  // WB champ → championship team1
        g3.feedsLoserTo = GameLink(gameId: g5.id, slot: .team1)   // WB final loser → LB R2

        // LB R1
        g4.feedsWinnerTo = GameLink(gameId: g5.id, slot: .team2)  // LB R1 winner → LB R2

        // LB R2 (LB Final)
        g5.feedsWinnerTo = GameLink(gameId: g6.id, slot: .team2)  // LB champ → championship team2

        // Championship: winner is champion (or if LB wins, if-necessary is activated via recordGameResult)

        // === Scheduled Times (Day 3 = Sunday April 26) ===
        g1.scheduledTime = gameTime(day: 26, hour: 9)           // 9:00 AM
        g2.scheduledTime = gameTime(day: 26, hour: 10, minute: 30)  // 10:30 AM
        g3.scheduledTime = gameTime(day: 26, hour: 12)          // 12:00 PM
        g4.scheduledTime = gameTime(day: 26, hour: 13, minute: 30)  // 1:30 PM
        g5.scheduledTime = gameTime(day: 26, hour: 15)          // 3:00 PM
        g6.scheduledTime = gameTime(day: 26, hour: 16, minute: 30)  // 4:30 PM
        g7.scheduledTime = gameTime(day: 26, hour: 18)          // 6:00 PM

        tier.games = [g1, g2, g3, g4, g5, g6, g7]

        tier.winnersBracketRounds = [
            BracketRoundGroup(name: "Round 1", gameIds: [g1.id, g2.id]),
            BracketRoundGroup(name: "Round 2", gameIds: [g3.id])
        ]

        tier.losersBracketRounds = [
            BracketRoundGroup(name: "Round 1", gameIds: [g4.id]),
            BracketRoundGroup(name: "Round 2", gameIds: [g5.id])
        ]

        tier.championshipGameId = g6.id
        tier.ifNecessaryGameId = g7.id
        tier.status = .upcoming

        return tier
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
