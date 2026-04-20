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
    /// Ensures the Rose City draft-pool unassign migration only runs once
    /// per app launch, even though the players listener fires repeatedly.
    private var didMigrateRoseCityDraftPool = false

    // MARK: - Write Helpers (with server-error reporting)

    /// Writes a Codable value to Firestore. Unlike the bare `setData(from:)` call,
    /// this captures **server-side** errors (permission denied, network failures
    /// after retry exhaustion, etc.) via the completion handler and surfaces them
    /// on `errorMessage` so the UI can display a sync problem to the user.
    ///
    /// Note: Firestore writes are queued locally first (so the local snapshot
    /// listeners fire immediately), then synced to the server. The completion
    /// closure runs only after the server acknowledges or rejects the write —
    /// which is why we need it to detect that data isn't actually reaching the
    /// cloud.
    private func writeDocument<T: Encodable>(_ value: T, to collection: String, id: String) {
        do {
            try db.collection(collection).document(id).setData(from: value) { [weak self] error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error {
                        let nsErr = error as NSError
                        print("[CloudSync] WRITE FAILED \(collection)/\(id): \(error.localizedDescription) (code=\(nsErr.code) domain=\(nsErr.domain))")
                        self.errorMessage = "Cloud sync failed (\(collection)): \(error.localizedDescription)"
                    } else {
                        print("[CloudSync] write OK \(collection)/\(id)")
                    }
                }
            }
        } catch {
            print("[CloudSync] ENCODING FAILED \(collection)/\(id): \(error)")
            errorMessage = "Encoding error (\(collection)): \(error.localizedDescription)"
        }
    }

    /// Deletes a document with completion-handler-based error reporting.
    private func deleteDocument(in collection: String, id: String) {
        db.collection(collection).document(id).delete { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    let nsErr = error as NSError
                    print("[CloudSync] DELETE FAILED \(collection)/\(id): \(error.localizedDescription) (code=\(nsErr.code) domain=\(nsErr.domain))")
                    self.errorMessage = "Cloud sync failed (\(collection)): \(error.localizedDescription)"
                } else {
                    print("[CloudSync] delete OK \(collection)/\(id)")
                }
            }
        }
    }

    // MARK: - Local Persistence Paths

    private static var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private static var playersFile: URL { documentsDir.appendingPathComponent("players.json") }
    private static var teamsFile: URL { documentsDir.appendingPathComponent("teams.json") }
    private static var tournamentFile: URL { documentsDir.appendingPathComponent("tournament.json") }

    init() {
        // Firestore offline persistence is enabled by default on iOS, so the
        // local cache survives across launches and reads work offline.
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
                        let nsErr = error as NSError
                        print("[CloudSync] players listener error: \(error.localizedDescription) (code=\(nsErr.code))")
                        self.errorMessage = "Players sync error: \(error.localizedDescription)"
                        return
                    }
                    guard let snapshot else { return }
                    let source = snapshot.metadata.isFromCache ? "cache" : "server"
                    print("[CloudSync] players snapshot: \(snapshot.documents.count) docs from \(source)")
                    self.players = snapshot.documents.compactMap { try? $0.data(as: Player.self) }
                    self.savePlayers()
                    self.runRoseCityDraftPoolMigrationIfNeeded()
                }
            }
        listeners.append(playersListener)

        let teamsListener = db.collection("teams")
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error {
                        let nsErr = error as NSError
                        print("[CloudSync] teams listener error: \(error.localizedDescription) (code=\(nsErr.code))")
                        self.errorMessage = "Teams sync error: \(error.localizedDescription)"
                        return
                    }
                    guard let snapshot else { return }
                    let source = snapshot.metadata.isFromCache ? "cache" : "server"
                    print("[CloudSync] teams snapshot: \(snapshot.documents.count) docs from \(source)")
                    self.teams = snapshot.documents.compactMap { try? $0.data(as: Team.self) }
                    self.saveTeams()
                }
            }
        listeners.append(teamsListener)

        // NOTE: We deliberately do NOT use `.order(by: "createdAt")` here.
        // Firestore's orderBy silently excludes any document missing that field,
        // which would make tournament docs written by older app versions (or
        // hand-edited in the console) invisible to viewers. Instead we fetch
        // every doc in the small `tournaments` collection and pick the latest
        // one client-side.
        let tournamentListener = db.collection("tournaments")
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error {
                        let nsErr = error as NSError
                        print("[CloudSync] tournament listener error: \(error.localizedDescription) (code=\(nsErr.code) domain=\(nsErr.domain))")
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
                    let source = snapshot.metadata.isFromCache ? "cache" : "server"
                    print("[CloudSync] tournament snapshot: \(snapshot.documents.count) docs from \(source) (pendingWrites=\(snapshot.metadata.hasPendingWrites))")

                    // Decode every doc; pick the most-recently-created one.
                    // Falls back gracefully if `createdAt` is missing.
                    let decoded: [Tournament] = snapshot.documents.compactMap { doc in
                        do {
                            return try doc.data(as: Tournament.self)
                        } catch {
                            print("[CloudSync] Failed to decode tournament \(doc.documentID): \(error)")
                            return nil
                        }
                    }

                    if let latest = decoded.max(by: { $0.createdAt < $1.createdAt }) {
                        self.tournament = latest
                        self.saveTournament()
                    } else if !snapshot.documents.isEmpty {
                        // Docs exist but none could be decoded — surface the error
                        // and keep any existing local copy rather than wiping it.
                        print("[CloudSync] tournament snapshot had \(snapshot.documents.count) doc(s) but none decoded")
                        self.errorMessage = "Failed to decode tourney data."
                    } else if !snapshot.metadata.isFromCache {
                        // Confirmed by SERVER: no tournament exists in Firestore.
                        // Don't null out from a stale cache snapshot — only trust the
                        // server's "empty" answer.
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
        writeDocument(player, to: "players", id: player.id)
        if let teamId,
           var team = teams.first(where: { $0.id == teamId }),
           !team.playerIds.contains(player.id) {
            team.playerIds.append(player.id)
            writeDocument(team, to: "teams", id: team.id)
        }
    }

    func updatePlayer(_ player: Player) async {
        writeDocument(player, to: "players", id: player.id)
    }

    func deletePlayer(_ player: Player) async {
        deleteDocument(in: "players", id: player.id)
        if let teamId = player.teamId,
           var team = teams.first(where: { $0.id == teamId }) {
            team.playerIds.removeAll { $0 == player.id }
            writeDocument(team, to: "teams", id: team.id)
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
        writeDocument(team, to: "teams", id: team.id)
    }

    func updateTeam(_ team: Team) async {
        writeDocument(team, to: "teams", id: team.id)
    }

    func deleteTeam(_ team: Team) async {
        for var player in players where player.teamId == team.id {
            player.teamId = nil
            writeDocument(player, to: "players", id: player.id)
        }
        deleteDocument(in: "teams", id: team.id)
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

    // MARK: - Draft Pools
    //
    // Some players are drafted into a team at tourney time rather than being
    // pre-rostered. They show up as free agents ("awaiting assignment") and,
    // when assigned, can only be placed on a restricted subset of teams.

    /// Mothership JV draft pool — these 8 players are drafted between the
    /// two Mothership JV squads (Reds / Blacks).
    static let mothershipJVDraftPool: Set<String> = [
        "The Surgeon", "8 Ball", "Stanklove", "Monkdank",
        "The Shepherd", "Long Balls", "Beverly Hills Cact", "Windows 95"
    ]
    static let mothershipJVDraftTeams: Set<String> = [
        "Mothership JV Reds", "Mothership JV Blacks"
    ]

    /// Rose City draft pool — these 6 players are assigned to either
    /// Rose City Champs or Rose City JV at tourney time.
    static let roseCityDraftPool: Set<String> = [
        "Honey Hamms", "Serial Killer", "The Wizard", "Holifield", "Cricket", "ShamWow"
    ]
    static let roseCityDraftTeams: Set<String> = [
        "Rose City Champs", "Rose City JV"
    ]

    /// One-time migration: move any Rose City draft pool players that were
    /// pre-rostered by earlier seed data back into the free agent pool so
    /// they can be re-drafted onto Rose City Champs or Rose City JV. Runs
    /// once per app launch after the players snapshot has arrived and at
    /// least a handful of players exist (to avoid racing the initial seed).
    func runRoseCityDraftPoolMigrationIfNeeded() {
        guard accessLevel == .admin else { return }
        guard !didMigrateRoseCityDraftPool else { return }
        guard players.count >= Self.roseCityDraftPool.count else { return }
        let draftees = players.filter {
            Self.roseCityDraftPool.contains($0.name) && $0.teamId != nil
        }
        // Mark migrated immediately — even if there's nothing to unassign,
        // we don't want to re-check on every subsequent snapshot.
        didMigrateRoseCityDraftPool = true
        guard !draftees.isEmpty else { return }
        Task { @MainActor in
            for player in draftees {
                await self.assignPlayerToTeam(playerId: player.id, teamId: nil)
            }
        }
    }

    /// Returns the subset of teams a given player is eligible to be assigned
    /// to. Players not in a restricted draft pool may be placed on any team.
    func allowedTeamsForPlayer(_ player: Player) -> [Team] {
        if Self.mothershipJVDraftPool.contains(player.name) {
            return teams.filter { Self.mothershipJVDraftTeams.contains($0.name) }
        }
        if Self.roseCityDraftPool.contains(player.name) {
            return teams.filter { Self.roseCityDraftTeams.contains($0.name) }
        }
        return teams
    }

    func seedTournamentPlayers() async {
        let existingNames = Set(players.map { $0.name })

        let teamRosters: [(teamName: String, players: [String])] = [
            ("Banditos",             ["The Rabbit", "Bandit Rick", "Wildcat", "Bandit Mitch", "Bandito Mayor"]),
            ("No Mames Wey Jovenes", ["Flacco", "The Future", "Chino", "Rookie Alex"]),
            ("Tinseltown JV",        ["Cuidado", "Dublé", "$alary", "Cojones", "Flashdance"]),
            ("D$$",                  ["Lil Diamond", "Cap'n", "Katfish", "Rooster", "Hell Yeah Why Not?"]),
            ("Steel City",           ["Solo Shot", "Clown Car", "Madre", "MidBen", "Mothman"]),
            ("Gold Coast",           ["The Mechanic", "Cocaine Greg", "The Big Puna", "The Rook", "Swingin Moe"]),
            ("Mothership Champs",    ["Soy Peligroso", "Jeffery Bomber", "Deep Space", "ODC", "Plough Jones"]),
            ("Jet City Champs",      ["Daisy Cutter", "Well Fed Man", "Dirt Bag", "AAA", "Deadliest Catch"]),
            ("Tinseltown Champs",    ["The Deal", "Dong Robber", "Lunch Money", "Candyman"]),
            ("No Mames Wey Viejos",  ["El Toro", "No Mas", "Rookie Ulee", "Pelone"]),
            // Rose City Champs has 3 set players; the rest of the Rose City
            // roster is drafted from the free agent pool below.
            ("Rose City Champs",     ["Big Trip", "Trees", "Almost Famous"]),
        ]

        for roster in teamRosters {
            guard let team = teams.first(where: { $0.name == roster.teamName }) else { continue }
            for playerName in roster.players where !existingNames.contains(playerName) {
                await addPlayer(name: playerName, teamId: team.id)
            }
        }

        // Mothership JV draft pool — free agents until drafted onto Reds/Blacks.
        for playerName in Self.mothershipJVDraftPool where !existingNames.contains(playerName) {
            await addPlayer(name: playerName, teamId: nil)
        }

        // Rose City draft pool — free agents until assigned to Champs or JV.
        for playerName in Self.roseCityDraftPool where !existingNames.contains(playerName) {
            await addPlayer(name: playerName, teamId: nil)
        }

        // Migration: any Rose City draft pool players that already exist with
        // a team assignment (from prior seeds) should be moved back to the
        // free agent pool so they can be re-drafted. Snapshot the list first
        // since `assignPlayerToTeam` mutates `players`.
        let roseCityDraftees = players.filter {
            Self.roseCityDraftPool.contains($0.name) && $0.teamId != nil
        }
        for player in roseCityDraftees {
            await assignPlayerToTeam(playerId: player.id, teamId: nil)
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

    /// Reset every draft pool player (Mothership JV Reds/Blacks and Rose City
    /// Champs/JV) back to the free agent pool so they can be re-drafted at
    /// the start of a new tournament. Each pool has its own eligibility
    /// restriction enforced by `allowedTeamsForPlayer`.
    func resetDraftPoolPlayersToFreeAgents() async {
        let draftees = players.filter {
            (Self.mothershipJVDraftPool.contains($0.name) ||
             Self.roseCityDraftPool.contains($0.name)) &&
            $0.teamId != nil
        }
        for player in draftees {
            await assignPlayerToTeam(playerId: player.id, teamId: nil)
        }
    }

    func createTournament(name: String, tierConfigs: [TierConfig]) async {
        // Reset draft pool players (Mothership JV Reds/Blacks, Rose City)
        // back to free agents so they can be re-drafted onto their eligible
        // teams for the new tournament.
        await resetDraftPoolPlayersToFreeAgents()

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
        // Optimistically update local state immediately so the UI reflects
        // the new tournament without waiting for the listener round-trip.
        self.tournament = tournament
        self.hasLoadedTournament = true
        saveTournament()
        writeDocument(tournament, to: "tournaments", id: tournament.id)
    }

    func updateTournament(_ tournament: Tournament) async {
        writeDocument(tournament, to: "tournaments", id: tournament.id)
    }

    /// Force-rewrite the local tournament document to Firestore. Use this to
    /// recover from the case where a previous write was rejected (e.g. by
    /// restrictive security rules) — the tournament still exists in the
    /// device's local cache but never reached the server, so other users see
    /// "no active tourney". After the rules are opened up, the admin can call
    /// this to push the local copy back to the cloud.
    func resyncTournamentToCloud() async {
        guard let tournament else {
            print("[CloudSync] resync skipped — no local tournament to upload")
            errorMessage = "No local tourney to re-sync."
            return
        }
        print("[CloudSync] resyncing tournament \(tournament.id) (\(tournament.name)) to cloud")
        writeDocument(tournament, to: "tournaments", id: tournament.id)
    }

    func deleteTournament() async {
        // Clear local state immediately so the UI reflects the delete without
        // waiting for the listener round-trip.
        self.tournament = nil
        saveTournament()

        // Delete EVERY document in the `tournaments` collection, not just the
        // one we happened to have cached locally. This guarantees the
        // collection is truly empty so that when a new tournament is created,
        // all users pick up the new doc as the single source of truth rather
        // than racing against orphan docs from earlier sessions.
        do {
            let snapshot = try await db.collection("tournaments").getDocuments()
            print("[CloudSync] deleteTournament clearing \(snapshot.documents.count) tournament doc(s)")
            for doc in snapshot.documents {
                deleteDocument(in: "tournaments", id: doc.documentID)
            }
        } catch {
            let nsErr = error as NSError
            print("[CloudSync] deleteTournament enumerate failed: \(error.localizedDescription) (code=\(nsErr.code))")
            errorMessage = "Failed to clear tourneys: \(error.localizedDescription)"
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

    /// Live-sync in-progress per-player stats for a game (dongs / salamies / double plays / drops).
    /// Writes are applied to the game's `playerGameStats` array without marking it completed,
    /// so scorekeepers can safely close and reopen the sheet without losing work.
    func updateGamePlayerStats(tierIndex: Int, gameId: String, playerStats: [PlayerGameStats]) async {
        guard var tournament else { return }
        guard tierIndex < tournament.tiers.count else { return }
        guard let gameIdx = tournament.tiers[tierIndex].games.firstIndex(where: { $0.id == gameId }) else { return }
        // Don't overwrite finalized games.
        guard tournament.tiers[tierIndex].games[gameIdx].status != .completed else { return }
        tournament.tiers[tierIndex].games[gameIdx].playerGameStats = playerStats
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
        // Games 1,2,5,6,9,10,11,13 → El Ruedo
        // Games 3,4,7,8,12 → El Ruedo II
        let ruedo = StickballField.elRuedo.rawValue
        let ruedoII = StickballField.elRuedoII.rawValue
        g1.field = ruedo;  g2.field = ruedo
        g3.field = ruedoII;    g4.field = ruedoII
        g5.field = ruedo;  g6.field = ruedo
        g7.field = ruedoII;    g8.field = ruedoII
        g9.field = ruedo;  g10.field = ruedo
        g11.field = ruedo; g12.field = ruedoII
        g13.field = ruedo

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

        // === Field Assignments — all Finals games at El Ruedo ===
        let elRuedo = StickballField.elRuedo.rawValue
        g1.field = elRuedo; g2.field = elRuedo
        g3.field = elRuedo; g4.field = elRuedo
        g5.field = elRuedo; g6.field = elRuedo
        g7.field = elRuedo

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

    func isTeamEliminated(_ teamId: String) -> Bool {
        guard let tournament else { return false }

        for tier in tournament.tiers {
            if tier.advancingTeamIds.contains(teamId) { return false }
        }

        var hasLost = false
        var hasUpcomingGame = false

        for tier in tournament.tiers {
            for game in tier.games {
                let isInGame = game.team1Id == teamId || game.team2Id == teamId
                guard isInGame else { continue }

                if game.status == .completed && game.loserId == teamId {
                    hasLost = true
                }
                if game.status == .pending || game.status == .inProgress {
                    hasUpcomingGame = true
                }
            }
        }

        return hasLost && !hasUpcomingGame
    }
}
