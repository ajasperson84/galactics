import SwiftUI

struct TournamentView: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @State private var showCreateTournament = false
    @State private var selectedGame: GameSelection?
    @State private var viewMode: ViewMode = .schedule
    @State private var selectedTierIndex: Int = 0
    @State private var showPinEntry = false

    enum ViewMode: String, CaseIterable {
        case schedule = "Schedule"
        case bracket = "Bracket"
    }

    struct GameSelection: Identifiable {
        let id = UUID()
        let tierIndex: Int
        let gameId: String
        let game: TournamentGame
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Cloud sync error banner — surfaces Firestore errors
                // (permission denied, offline, etc.) so the user actually
                // sees when their changes aren't reaching the server.
                if let errorMessage = cloudService.errorMessage {
                    SyncErrorBanner(message: errorMessage) {
                        cloudService.errorMessage = nil
                    }
                    .padding(.horizontal)
                }

                if let tournament = cloudService.tournament {
                    // Trash button (admin only)
                    if cloudService.accessLevel == .admin {
                        HStack {
                            Spacer()
                            Button {
                                Task {
                                    await cloudService.deleteTournament()
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(AztecTheme.bloodRed)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Champion display
                    if tournament.status == .completed,
                       let lastTier = tournament.tiers.last {
                        let champGameId = lastTier.ifNecessaryGameId ?? lastTier.championshipGameId
                        if let champId = champGameId,
                           let champGame = lastTier.game(byId: champId),
                           champGame.status == .completed,
                           let winnerId = champGame.winnerId,
                           let champion = cloudService.team(for: winnerId) {
                            ChampionBanner(teamName: champion.name, winnerId: winnerId)
                                .padding(.horizontal)
                        }
                    }

                    // View mode toggle: Schedule / Bracket
                    Picker("View", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Tier selector buttons — full width
                    if tournament.tiers.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(Array(tournament.tiers.enumerated()), id: \.element.id) { index, tier in
                                Button {
                                    selectedTierIndex = index
                                } label: {
                                    let isSelected = selectedTierIndex == index
                                    let color = index % 2 == 0 ? AztecTheme.neonYellow : AztecTheme.hotPink
                                    VStack(spacing: 2) {
                                        Text(tier.dayLabel.uppercased())
                                            .font(AztecTheme.sfProBold(size: 11))
                                        Text(tier.tierName.uppercased())
                                            .font(AztecTheme.sfProBold(size: 14))
                                    }
                                    .foregroundColor(isSelected ? Color.black : color)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? color : Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(color, lineWidth: 2.25)
                                    )
                                    .shadow(color: isSelected ? color.opacity(0.4) : .clear, radius: 4)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Content based on view mode
                    let tierIdx = min(selectedTierIndex, tournament.tiers.count - 1)
                    let tier = tournament.tiers[tierIdx]

                    switch viewMode {
                    case .schedule:
                        ScheduleView(tier: tier, tierIndex: tierIdx) { game in
                            selectedGame = GameSelection(tierIndex: tierIdx, gameId: game.id, game: game)
                        }
                    case .bracket:
                        BracketView(tier: tier, tierIndex: tierIdx) { game in
                            selectedGame = GameSelection(tierIndex: tierIdx, gameId: game.id, game: game)
                        }
                    }
                } else if !cloudService.hasLoadedTournament {
                    // Still waiting for the first Firestore snapshot — show a loader
                    // instead of flashing "NO ACTIVE TOURNEY" at viewers who have no
                    // cached tournament on disk yet.
                    VStack(spacing: 20) {
                        Spacer().frame(height: 60)

                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AztecTheme.neonYellow))
                            .scaleEffect(1.5)

                        Text("LOADING TOURNEY…")
                            .font(AztecTheme.hobbsFont(size: 28))
                            .tracking(AztecTheme.hobbsKerning)
                            .foregroundColor(AztecTheme.neonYellow)
                            .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 4)
                    }
                } else {
                    // No tournament
                    VStack(spacing: 24) {
                        Spacer().frame(height: 40)

                        ZStack {
                            Circle()
                                .fill(AztecTheme.hotPink.opacity(0.08))
                                .frame(width: 120, height: 120)

                            Image(systemName: "trophy.fill")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(AztecTheme.neonYellow)
                                .shadow(color: AztecTheme.neonYellow.opacity(0.5), radius: 8)
                                .shadow(color: AztecTheme.neonYellow.opacity(0.2), radius: 16)
                        }

                        Text("NO ACTIVE TOURNEY")
                            .font(AztecTheme.hobbsFont(size: 32))
                            .tracking(AztecTheme.hobbsKerning)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundColor(AztecTheme.neonYellow)

                        Text("Create a tourney to set up brackets\nand start tracking games.")
                            .font(AztecTheme.sfProMedium(size: 16))
                            .foregroundColor(AztecTheme.hotPink)
                            .multilineTextAlignment(.center)

                        if cloudService.accessLevel == .admin {
                            Button("CREATE TOURNEY") {
                                showCreateTournament = true
                            }
                            .buttonStyle(AztecButtonStyle())
                        }

                        // Lock button
                        Spacer().frame(height: 16)
                        Button {
                            showPinEntry = true
                        } label: {
                            let isUnlocked = cloudService.accessLevel != .viewOnly
                            HStack(spacing: 6) {
                                Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                                    .font(.system(size: 16, weight: .bold))
                                if isUnlocked {
                                    Text(cloudService.accessLevel == .admin ? "ADMIN" : "SCOREKEEPER")
                                        .font(AztecTheme.sfProBold(size: 10))
                                        .tracking(1)
                                }
                            }
                            .foregroundColor(isUnlocked ? AztecTheme.neonYellow : AztecTheme.hotPink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(
                                        isUnlocked ? AztecTheme.neonYellow.opacity(0.5) : AztecTheme.hotPink.opacity(0.4),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(color: isUnlocked ? AztecTheme.neonYellow.opacity(0.3) : .clear, radius: 4)
                        }
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showPinEntry) {
            PinEntrySheet()
        }
        .sheet(isPresented: $showCreateTournament) {
            CreateTournamentSheet()
        }
        .sheet(item: $selectedGame) { selection in
            if selection.game.team1Id != nil && selection.game.team2Id != nil {
                GameEntrySheet(tierIndex: selection.tierIndex, game: selection.game)
            } else if cloudService.accessLevel == .admin {
                TeamAssignmentSheet(tierIndex: selection.tierIndex, gameId: selection.gameId)
            } else {
                GameEntrySheet(tierIndex: selection.tierIndex, game: selection.game)
            }
        }
    }
}

// MARK: - Champion Banner

struct ChampionBanner: View {
    @EnvironmentObject var cloudService: CloudSyncService
    let teamName: String
    var winnerId: String?

    var body: some View {
        VStack(spacing: 8) {
            if let winnerId, let team = cloudService.team(for: winnerId) {
                TeamIconView(team: team, size: 64)
                    .shadow(color: AztecTheme.hotPink.opacity(0.6), radius: 10)
            }

            Image(systemName: "trophy.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(AztecTheme.neonYellow)
                .shadow(color: AztecTheme.neonYellow.opacity(0.7), radius: 6)
                .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 12)

            Text("CHAMPION")
                .font(AztecTheme.hobbsFont(size: 28))
                .tracking(AztecTheme.hobbsKerning)
                .foregroundColor(AztecTheme.hotPink)
                .shadow(color: AztecTheme.hotPink.opacity(0.5), radius: 4)

            Text(teamName.uppercased())
                .font(AztecTheme.hobbsFont(size: 50))
                .tracking(AztecTheme.hobbsKerning)
                .foregroundColor(AztecTheme.neonYellow)
                .shadow(color: AztecTheme.neonYellow.opacity(0.5), radius: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .neonCard(border: AztecTheme.neonYellow)
    }
}

// MARK: - Game Card (used by both Schedule and Bracket views)

struct GameCard: View {
    @EnvironmentObject var cloudService: CloudSyncService
    let game: TournamentGame
    var tier: TournamentTier?
    var compact: Bool = false
    var onTap: (() -> Void)?

    private var team1: Team? {
        game.team1Id.flatMap { cloudService.team(for: $0) }
    }

    private var team2: Team? {
        game.team2Id.flatMap { cloudService.team(for: $0) }
    }

    private var team1DisplayName: String {
        if let team = team1 { return team.name }
        if let tier { return tier.slotDescription(gameId: game.id, slot: .team1) }
        return "TBD"
    }

    private var team2DisplayName: String {
        if let team = team2 { return team.name }
        if let tier { return tier.slotDescription(gameId: game.id, slot: .team2) }
        return "TBD"
    }

    private var statusLabel: String {
        switch game.status {
        case .pending:
            if let time = game.scheduledTime {
                let timeStr = time.formatted(.dateTime.hour().minute())
                // Show day name if game is on a different day than the tier's date
                if let tierDate = tier?.date,
                   !Calendar.current.isDate(time, inSameDayAs: tierDate) {
                    let dayName = time.formatted(.dateTime.weekday(.wide)).uppercased()
                    return "\(timeStr) - \(dayName)"
                }
                return timeStr
            }
            return ""
        case .inProgress:
            if let inning = game.currentInning {
                return "INN \(inning)"
            }
            return "LIVE"
        case .completed: return "FINAL"
        }
    }

    private var team1Color: Color {
        if game.team1Id == nil { return AztecTheme.dimText }
        if game.status == .completed && game.winnerId != game.team1Id { return AztecTheme.dimText }
        return AztecTheme.neonYellow
    }

    private var team2Color: Color {
        if game.team2Id == nil { return AztecTheme.dimText }
        if game.status == .completed && game.winnerId != game.team2Id { return AztecTheme.dimText }
        return AztecTheme.hotPink
    }

    private var statusColor: Color {
        switch game.status {
        case .pending: return AztecTheme.dimText
        case .inProgress: return AztecTheme.neonYellow
        case .completed: return AztecTheme.hotPink
        }
    }

    @ViewBuilder
    private func scheduleTeamName(_ name: String, color: Color, trailing: Bool = false) -> some View {
        let lines = splitForSchedule(name)
        if lines.count > 1 {
            VStack(spacing: 0) {
                ForEach(lines, id: \.self) { line in
                    Text(line.uppercased())
                        .font(AztecTheme.sfProBold(size: compact ? 11 : 14))
                        .foregroundColor(color)
                        .shadow(color: color.opacity(game.team1Id != nil || game.team2Id != nil ? 0.5 : 0), radius: 4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                }
            }
        } else {
            Text(name.uppercased())
                .font(AztecTheme.sfProBold(size: compact ? 12 : 16))
                .foregroundColor(color)
                .shadow(color: color.opacity(game.team1Id != nil || game.team2Id != nil ? 0.5 : 0), radius: 4)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
        }
    }

    private func splitForSchedule(_ name: String) -> [String] {
        if name.hasPrefix("Mothership JV") {
            return ["Mothership", String(name.dropFirst("Mothership ".count))]
        }
        if name.hasPrefix("No Mames Wey") && name.count > "No Mames Wey".count {
            return ["No Mames Wey", String(name.dropFirst("No Mames Wey ".count))]
        }
        return [name]
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: compact ? 4 : 8) {
                // Header: Game #, field, status
                HStack {
                    Text("GAME \(game.gameNumber)")
                        .font(AztecTheme.sfProBold(size: compact ? 10 : 12))
                        .foregroundColor(AztecTheme.neonYellow)

                    if let field = game.field {
                        Text(field.uppercased())
                            .font(AztecTheme.sfProBold(size: compact ? 8 : 10))
                            .foregroundColor(AztecTheme.hotPink)
                    }

                    Spacer()

                    Text(statusLabel)
                        .font(AztecTheme.sfProBold(size: compact ? 9 : 11))
                        .foregroundColor(statusColor)
                }

                // Teams and score
                HStack(spacing: 0) {
                    // Team 1 column
                    VStack(spacing: compact ? 2 : 4) {
                        HStack(spacing: 4) {
                            if let team = team1, !compact {
                                TeamIconView(team: team, size: 30, glowRadius: 6)
                            }
                            scheduleTeamName(team1DisplayName, color: team1Color)
                        }

                        if game.status == .completed || game.status == .inProgress {
                            let isWinner = game.winnerId == game.team1Id && game.status == .completed
                            Text("\(game.team1Score)")
                                .font(AztecTheme.hobbsFont(size: compact ? 20 : 28))
                                .tracking(AztecTheme.hobbsKerning)
                                .foregroundColor(AztecTheme.neonYellow)
                                .shadow(color: AztecTheme.neonYellow.opacity(isWinner ? 0.9 : 0.2), radius: isWinner ? 10 : 2)
                                .shadow(color: AztecTheme.neonYellow.opacity(isWinner ? 0.6 : 0), radius: isWinner ? 16 : 0)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // VS always visible
                    Text("VS")
                        .font(AztecTheme.hobbsFont(size: compact ? 32 : 43))
                        .tracking(AztecTheme.hobbsKerning)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AztecTheme.neonYellow, AztecTheme.hotPink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 4)
                        .offset(y: (game.status == .completed || game.status == .inProgress) ? (compact ? -4 : -6) : 0)

                    // Team 2 column
                    VStack(spacing: compact ? 2 : 4) {
                        HStack(spacing: 4) {
                            scheduleTeamName(team2DisplayName, color: team2Color, trailing: true)
                            if let team = team2, !compact {
                                TeamIconView(team: team, size: 30, glowRadius: 6)
                            }
                        }

                        if game.status == .completed || game.status == .inProgress {
                            let isWinner = game.winnerId == game.team2Id && game.status == .completed
                            Text("\(game.team2Score)")
                                .font(AztecTheme.hobbsFont(size: compact ? 20 : 28))
                                .tracking(AztecTheme.hobbsKerning)
                                .foregroundColor(AztecTheme.hotPink)
                                .shadow(color: AztecTheme.hotPink.opacity(isWinner ? 0.9 : 0.2), radius: isWinner ? 10 : 2)
                                .shadow(color: AztecTheme.hotPink.opacity(isWinner ? 0.6 : 0), radius: isWinner ? 16 : 0)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Assign teams hint — only for "To Be Drawn" slots, not auto-populated ones
                if let tier {
                    let hasDrawSlot = (game.team1Id == nil && tier.slotDescription(gameId: game.id, slot: .team1) == "To Be Drawn") ||
                        (game.team2Id == nil && tier.slotDescription(gameId: game.id, slot: .team2) == "To Be Drawn")
                    if hasDrawSlot && cloudService.accessLevel == .admin {
                        Text("TAP TO ASSIGN TEAMS")
                            .font(AztecTheme.sfProBold(size: 10))
                            .tracking(1)
                            .foregroundColor(AztecTheme.neonYellow)
                            .padding(.top, 2)
                    }
                }

            }
            .padding(compact ? 8 : 12)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 8 : 12))
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 8 : 12)
                    .stroke(AztecTheme.borderGradient, lineWidth: 2.4)
            )
            .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 6, x: -2)
            .shadow(color: AztecTheme.hotPink.opacity(0.3), radius: 6, x: 2)
            .shadow(color: game.status == .inProgress ? AztecTheme.neonYellow.opacity(0.4) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create Tournament Sheet

struct CreateTournamentSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    @State private var isCreating = false

    private let day1Date = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 24))!
    private let day2Date = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 25))!
    private let day3Date = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 26))!

    private let day1TeamNames = [
        "Mothership JV Reds", "Mothership JV Blacks",
        "Tinseltown JV", "Rose City JV",
        "D$$", "Steel City", "Gold Coast",
        "Banditos", "No Mames Wey Jovenes"
    ]

    private let day2TeamNames = [
        "Mothership Champs", "Tinseltown Champs",
        "Rose City Champs", "Jet City Champs",
        "No Mames Wey Viejos"
    ]

    private var day1TeamIds: [String] {
        day1TeamNames.compactMap { name in
            cloudService.teams.first { $0.name == name }?.id
        }
    }

    private var day2TeamIds: [String] {
        day2TeamNames.compactMap { name in
            cloudService.teams.first { $0.name == name }?.id
        }
    }

    private var allTeamsSeeded: Bool {
        day1TeamIds.count == 9 && day2TeamIds.count == 5
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        AztecSectionHeader(title: "G Four Setup")

                        if !allTeamsSeeded {
                            Text("All 14 teams must be seeded before creating the tourney.")
                                .font(AztecTheme.sfProMedium(size: 14))
                                .foregroundColor(AztecTheme.hotPink)
                                .multilineTextAlignment(.center)

                            Button("SEED ALL G4 TEAMS") {
                                Task {
                                    await cloudService.seedTournamentTeams()
                                }
                            }
                            .buttonStyle(AztecButtonStyle())

                            Button("SEED ALL PLAYERS") {
                                Task {
                                    await cloudService.seedTournamentPlayers()
                                }
                            }
                            .buttonStyle(AztecButtonStyle(color: AztecTheme.hotPink))
                        }

                        // Day 1 summary
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DAY 1 (FRIDAY)")
                                .font(AztecTheme.sfProBold(size: 14))
                                .foregroundColor(AztecTheme.neonYellow)
                            ForEach(day1TeamNames, id: \.self) { name in
                                let found = cloudService.teams.contains { $0.name == name }
                                HStack(spacing: 6) {
                                    Image(systemName: found ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 10))
                                        .foregroundColor(found ? AztecTheme.neonYellow : AztecTheme.dimText)
                                    Text(name)
                                        .font(AztecTheme.sfProMedium(size: 12))
                                        .foregroundColor(found ? AztecTheme.lightText : AztecTheme.dimText)
                                }
                            }
                        }
                        .padding()
                        .neonCard()

                        // Day 2 summary
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DAY 2 (SATURDAY) — 5 + 3 advancing")
                                .font(AztecTheme.sfProBold(size: 14))
                                .foregroundColor(AztecTheme.hotPink)
                            ForEach(day2TeamNames, id: \.self) { name in
                                let found = cloudService.teams.contains { $0.name == name }
                                HStack(spacing: 6) {
                                    Image(systemName: found ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 10))
                                        .foregroundColor(found ? AztecTheme.neonYellow : AztecTheme.dimText)
                                    Text(name)
                                        .font(AztecTheme.sfProMedium(size: 12))
                                        .foregroundColor(found ? AztecTheme.lightText : AztecTheme.dimText)
                                }
                            }
                            Text("+ 3 winners from Day 1")
                                .font(AztecTheme.sfProMedium(size: 12))
                                .foregroundColor(AztecTheme.dimText)
                        }
                        .padding()
                        .neonCard()

                        // Finals summary
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FINALS (SUNDAY)")
                                .font(AztecTheme.sfProBold(size: 14))
                                .foregroundColor(AztecTheme.neonYellow)
                            Text("Top 4 finishers from Day 2")
                                .font(AztecTheme.sfProMedium(size: 12))
                                .foregroundColor(AztecTheme.dimText)
                        }
                        .padding()
                        .neonCard()

                        if allTeamsSeeded && cloudService.players.count < 50 {
                            Button("SEED ALL PLAYERS") {
                                Task {
                                    await cloudService.seedTournamentPlayers()
                                }
                            }
                            .buttonStyle(AztecButtonStyle(color: AztecTheme.hotPink))
                        }

                        if allTeamsSeeded {
                            Button("START TOURNEY") {
                                isCreating = true
                                Task {
                                    let configs = [
                                        CloudSyncService.TierConfig(
                                            tierNumber: 1,
                                            tierName: "Day 1",
                                            dayLabel: "Friday",
                                            date: day1Date,
                                            teamIds: day1TeamIds
                                        ),
                                        CloudSyncService.TierConfig(
                                            tierNumber: 2,
                                            tierName: "Day 2",
                                            dayLabel: "Saturday",
                                            date: day2Date,
                                            teamIds: day2TeamIds
                                        ),
                                        CloudSyncService.TierConfig(
                                            tierNumber: 3,
                                            tierName: "Finals",
                                            dayLabel: "Sunday",
                                            date: day3Date,
                                            teamIds: []
                                        ),
                                    ]
                                    await cloudService.createTournament(
                                        name: "G Four",
                                        tierConfigs: configs
                                    )
                                    dismiss()
                                }
                            }
                            .buttonStyle(AztecButtonStyle())
                            .disabled(isCreating)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("New Tourney")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .dismissButtonStyle()
                }
            }
        }
    }
}

// MARK: - Team Assignment Sheet

struct TeamAssignmentSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss

    let tierIndex: Int
    let gameId: String

    private var game: TournamentGame? {
        guard let tournament = cloudService.tournament,
              tierIndex < tournament.tiers.count else { return nil }
        return tournament.tiers[tierIndex].game(byId: gameId)
    }

    private var availableTeams: [Team] {
        let unassigned = cloudService.unassignedTierTeams(tierIndex: tierIndex)
        let losers = cloudService.unplacedLosers(tierIndex: tierIndex)
        let combined = Set(unassigned + losers)
        return combined
            .compactMap { cloudService.team(for: $0) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let game {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header
                            Text("GAME \(game.gameNumber)")
                                .font(AztecTheme.hobbsFont(size: 40))
                                .tracking(AztecTheme.hobbsKerning)
                                .foregroundColor(AztecTheme.neonYellow)
                                .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 4)

                            Text("ASSIGN TEAMS")
                                .font(AztecTheme.sfProBold(size: 14))
                                .tracking(2)
                                .foregroundColor(AztecTheme.hotPink)
                                .shadow(color: AztecTheme.hotPink.opacity(0.4), radius: 3)

                            // Team 1 slot
                            let needsTeam1 = game.team1Id == nil &&
                                !cloudService.slotHasAutoFeed(tierIndex: tierIndex, gameId: gameId, slot: .team1)

                            if let teamId = game.team1Id, let team = cloudService.team(for: teamId) {
                                assignedRow(team: team, label: "TEAM 1")
                            } else if needsTeam1 {
                                slotPicker(title: "SELECT TEAM 1", slot: .team1)
                            } else {
                                pendingRow(label: "TEAM 1 — waiting for result")
                            }

                            Text("VS")
                                .font(AztecTheme.hobbsFont(size: 40))
                                .tracking(AztecTheme.hobbsKerning)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AztecTheme.neonYellow, AztecTheme.hotPink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            // Team 2 slot
                            let needsTeam2 = game.team2Id == nil &&
                                !cloudService.slotHasAutoFeed(tierIndex: tierIndex, gameId: gameId, slot: .team2)

                            if let teamId = game.team2Id, let team = cloudService.team(for: teamId) {
                                assignedRow(team: team, label: "TEAM 2")
                            } else if needsTeam2 {
                                slotPicker(title: "SELECT TEAM 2", slot: .team2)
                            } else {
                                pendingRow(label: "TEAM 2 — waiting for result")
                            }

                            if game.team1Id != nil && game.team2Id != nil {
                                Text("BOTH TEAMS ASSIGNED")
                                    .font(AztecTheme.sfProBold(size: 12))
                                    .tracking(1)
                                    .foregroundColor(AztecTheme.neonYellow)
                                    .padding(.top, 8)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Assign Teams")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .dismissButtonStyle()
                }
            }
        }
    }

    private func slotPicker(title: String, slot: TeamSlot) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(AztecTheme.sfProBold(size: 11))
                .tracking(2)
                .foregroundColor(AztecTheme.hotPink)

            if availableTeams.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AztecTheme.dimText)
                    Text("Waiting for teams...")
                        .font(AztecTheme.sfProMedium(size: 14))
                        .foregroundColor(AztecTheme.dimText)
                }
                .padding()
            } else {
                ForEach(availableTeams) { team in
                    Button {
                        Task {
                            await cloudService.assignTeamToGameSlot(
                                tierIndex: tierIndex,
                                gameId: gameId,
                                slot: slot,
                                teamId: team.id
                            )
                        }
                    } label: {
                        HStack {
                            TeamIconView(team: team, size: 28)
                            Text(team.name)
                                .font(AztecTheme.hobbsFont(size: 28))
                                .tracking(AztecTheme.hobbsKerning)
                                .foregroundColor(AztecTheme.neonYellow)
                            Spacer()
                            Image(systemName: "plus.circle")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AztecTheme.hotPink)
                        }
                        .padding(14)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AztecTheme.hotPink.opacity(0.4), lineWidth: 2.25)
                        )
                    }
                }
            }
        }
    }

    private func assignedRow(team: Team, label: String) -> some View {
        HStack {
            TeamIconView(team: team, size: 32)
            Text(team.name)
                .font(AztecTheme.hobbsFont(size: 32))
                .tracking(AztecTheme.hobbsKerning)
                .foregroundColor(AztecTheme.neonYellow)
            Spacer()
            Text(label)
                .font(AztecTheme.sfProBold(size: 10))
                .foregroundColor(AztecTheme.hotPink)
        }
        .padding(14)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AztecTheme.neonYellow.opacity(0.6), lineWidth: 2.25)
        )
    }

    private func pendingRow(label: String) -> some View {
        HStack {
            Image(systemName: "hourglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AztecTheme.dimText)
            Text(label)
                .font(AztecTheme.sfProMedium(size: 14))
                .foregroundColor(AztecTheme.dimText)
            Spacer()
        }
        .padding(14)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AztecTheme.hotPink.opacity(0.2), lineWidth: 2.25)
        )
    }
}
