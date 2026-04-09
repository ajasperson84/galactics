import SwiftUI

struct TournamentView: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @State private var showCreateTournament = false
    @State private var selectedGame: GameSelection?
    @State private var viewMode: ViewMode = .schedule
    @State private var selectedTierIndex: Int = 0

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
                if let tournament = cloudService.tournament {
                    // Trash button
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

                    // Tier selector pills
                    if tournament.tiers.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
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
                                        .padding(.horizontal, 16)
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
                    }

                    // Content based on view mode
                    let tierIdx = min(selectedTierIndex, tournament.tiers.count - 1)
                    let tier = tournament.tiers[tierIdx]

                    // Team assignment banner
                    let needsAssignment = !cloudService.unassignedTierTeams(tierIndex: tierIdx).isEmpty ||
                        !cloudService.unplacedLosers(tierIndex: tierIdx).isEmpty
                    if needsAssignment {
                        HStack(spacing: 8) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AztecTheme.neonYellow)
                            Text("TEAMS NEED ASSIGNING")
                                .font(AztecTheme.sfProBold(size: 12))
                                .tracking(1)
                                .foregroundColor(AztecTheme.neonYellow)
                            Spacer()
                            Text("Tap a game to assign")
                                .font(AztecTheme.sfProMedium(size: 11))
                                .foregroundColor(AztecTheme.hotPink)
                        }
                        .padding(12)
                        .background(AztecTheme.neonYellow.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AztecTheme.neonYellow.opacity(0.4), lineWidth: 1.5)
                        )
                        .padding(.horizontal)
                    }

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

                        if cloudService.teams.count >= 2 {
                            Button("CREATE TOURNEY") {
                                showCreateTournament = true
                            }
                            .buttonStyle(AztecButtonStyle())
                        } else {
                            Text("Add at least 2 squads to create a tourney")
                                .font(AztecTheme.sfProBold(size: 14))
                                .foregroundColor(AztecTheme.hotPink)
                        }
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showCreateTournament) {
            CreateTournamentSheet()
        }
        .sheet(item: $selectedGame) { selection in
            if selection.game.team1Id != nil && selection.game.team2Id != nil {
                GameEntrySheet(tierIndex: selection.tierIndex, game: selection.game)
            } else {
                TeamAssignmentSheet(tierIndex: selection.tierIndex, gameId: selection.gameId)
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
    var compact: Bool = false
    var onTap: (() -> Void)?

    private var team1: Team? {
        game.team1Id.flatMap { cloudService.team(for: $0) }
    }

    private var team2: Team? {
        game.team2Id.flatMap { cloudService.team(for: $0) }
    }

    private var bracketLabel: String {
        switch game.bracketSide {
        case .winners: return "WB"
        case .losers: return "LB"
        case .championship: return "CHAMP"
        case .ifNecessary: return "IF NEC"
        }
    }

    private var bracketColor: Color {
        switch game.bracketSide {
        case .winners: return AztecTheme.neonYellow
        case .losers: return AztecTheme.hotPink
        case .championship, .ifNecessary: return AztecTheme.neonYellow
        }
    }

    private var statusLabel: String {
        switch game.status {
        case .pending: return "UPCOMING"
        case .inProgress: return "LIVE"
        case .completed: return "FINAL"
        }
    }

    private var statusColor: Color {
        switch game.status {
        case .pending: return AztecTheme.dimText
        case .inProgress: return AztecTheme.neonYellow
        case .completed: return AztecTheme.hotPink
        }
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: compact ? 4 : 8) {
                // Header: Game #, bracket tag, status
                HStack {
                    Text("GAME \(game.gameNumber)")
                        .font(AztecTheme.sfProBold(size: compact ? 10 : 12))
                        .foregroundColor(AztecTheme.neonYellow)

                    Text(bracketLabel)
                        .font(AztecTheme.sfProBold(size: compact ? 8 : 10))
                        .foregroundColor(Color.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(bracketColor)
                        .clipShape(Capsule())

                    Spacer()

                    Text(statusLabel)
                        .font(AztecTheme.sfProBold(size: compact ? 9 : 11))
                        .foregroundColor(statusColor)
                }

                // Teams and score
                HStack(spacing: 0) {
                    // Team 1
                    HStack(spacing: 4) {
                        if let team = team1, let icon = team.iconName, !compact {
                            Image(icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                        }
                        Text(team1?.name.uppercased() ?? "TBD")
                            .font(AztecTheme.sfProBold(size: compact ? 12 : 16))
                            .foregroundColor(game.winnerId == game.team1Id && game.status == .completed
                                ? AztecTheme.neonYellow
                                : (game.status == .completed && game.winnerId != game.team1Id
                                    ? AztecTheme.dimText
                                    : AztecTheme.neonYellow))
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if game.status == .completed || game.status == .inProgress {
                        Text("\(game.team1Score)")
                            .font(.system(size: compact ? 16 : 22, weight: .black, design: .monospaced))
                            .foregroundColor(AztecTheme.neonYellow)
                        Text("-")
                            .font(AztecTheme.sfProBold(size: compact ? 12 : 16))
                            .foregroundColor(AztecTheme.hotPink)
                            .padding(.horizontal, 4)
                        Text("\(game.team2Score)")
                            .font(.system(size: compact ? 16 : 22, weight: .black, design: .monospaced))
                            .foregroundColor(AztecTheme.hotPink)
                    } else {
                        Text("VS")
                            .font(AztecTheme.hobbsFont(size: compact ? 18 : 24))
                            .tracking(AztecTheme.hobbsKerning)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AztecTheme.neonYellow, AztecTheme.hotPink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }

                    // Team 2
                    HStack(spacing: 4) {
                        Text(team2?.name.uppercased() ?? "TBD")
                            .font(AztecTheme.sfProBold(size: compact ? 12 : 16))
                            .foregroundColor(game.winnerId == game.team2Id && game.status == .completed
                                ? AztecTheme.hotPink
                                : (game.status == .completed && game.winnerId != game.team2Id
                                    ? AztecTheme.dimText
                                    : AztecTheme.hotPink))
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                        if let team = team2, let icon = team.iconName, !compact {
                            Image(icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // Assign teams hint
                if game.team1Id == nil || game.team2Id == nil {
                    Text("TAP TO ASSIGN TEAMS")
                        .font(AztecTheme.sfProBold(size: 10))
                        .tracking(1)
                        .foregroundColor(AztecTheme.neonYellow)
                        .padding(.top, 2)
                }

                // Field and time info (non-compact only)
                if !compact {
                    HStack(spacing: 12) {
                        if let time = game.scheduledTime {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(AztecTheme.neonYellow)
                                Text(time.formatted(.dateTime.hour().minute()))
                                    .font(AztecTheme.sfProBold(size: 12))
                                    .foregroundColor(AztecTheme.neonYellow)
                            }
                        }
                        if let field = game.field {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(AztecTheme.hotPink)
                                Text(field)
                                    .font(AztecTheme.sfProBold(size: 12))
                                    .foregroundColor(AztecTheme.neonYellow)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding(compact ? 8 : 12)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 8 : 12))
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 8 : 12)
                    .stroke(
                        game.status == .completed
                            ? AztecTheme.hotPink.opacity(0.5)
                            : (game.status == .inProgress
                                ? AztecTheme.neonYellow
                                : AztecTheme.hotPink.opacity(0.3)),
                        lineWidth: 2.25
                    )
            )
            .shadow(color: game.status == .inProgress ? AztecTheme.neonYellow.opacity(0.3) : .clear, radius: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create Tournament Sheet

struct CreateTournamentSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    @State private var step = 1
    @State private var tier1TeamIds: [String] = []
    @State private var tier2TeamIds: [String] = []
    @State private var day1Date = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 25))!
    @State private var day2Date = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 26))!
    @State private var day3Date = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 27))!

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if step == 1 {
                            // Step 1: Select teams for Tier 1 (Day 1)
                            AztecSectionHeader(title: "G Four Setup")

                            Text("Select squads for Day 1 (Round 1).\nRemaining squads enter on Day 2.")
                                .font(AztecTheme.sfProMedium(size: 14))
                                .foregroundColor(AztecTheme.hotPink)
                                .multilineTextAlignment(.center)

                            if cloudService.teams.count < 14 {
                                Button("SEED ALL G4 TEAMS") {
                                    Task {
                                        await cloudService.seedTournamentTeams()
                                    }
                                }
                                .buttonStyle(AztecSecondaryButtonStyle(color: AztecTheme.hotPink))
                            }

                            AztecSectionHeader(title: "Day 1 Squads (\(tier1TeamIds.count))", color: AztecTheme.hotPink)

                            ForEach(cloudService.teams) { team in
                                Button {
                                    if let idx = tier1TeamIds.firstIndex(of: team.id) {
                                        tier1TeamIds.remove(at: idx)
                                    } else {
                                        tier2TeamIds.removeAll { $0 == team.id }
                                        tier1TeamIds.append(team.id)
                                    }
                                } label: {
                                    teamSelectionRow(team: team, isSelected: tier1TeamIds.contains(team.id), label: "Day 1")
                                }
                            }

                            if tier1TeamIds.count >= 2 {
                                Button("NEXT: DAY 2 SQUADS") {
                                    step = 2
                                }
                                .buttonStyle(AztecButtonStyle())
                            } else {
                                Text("Select at least 2 squads for Day 1")
                                    .font(AztecTheme.sfProBold(size: 14))
                                    .foregroundColor(AztecTheme.hotPink)
                            }
                        } else if step == 2 {
                            // Step 2: Select teams entering on Day 2
                            AztecSectionHeader(title: "Day 2 Squads")

                            Text("Select squads waiting for Day 2.\n3 winners from Day 1 will join them.")
                                .font(AztecTheme.sfProMedium(size: 14))
                                .foregroundColor(AztecTheme.hotPink)
                                .multilineTextAlignment(.center)

                            if !tier2TeamIds.isEmpty {
                                Text("\(tier2TeamIds.count) selected + 3 advancing = \(tier2TeamIds.count + 3) total")
                                    .font(AztecTheme.sfProBold(size: 13))
                                    .foregroundColor(AztecTheme.neonYellow)
                            }

                            let availableForDay2 = cloudService.teams.filter { !tier1TeamIds.contains($0.id) }
                            ForEach(availableForDay2) { team in
                                Button {
                                    if let idx = tier2TeamIds.firstIndex(of: team.id) {
                                        tier2TeamIds.remove(at: idx)
                                    } else {
                                        tier2TeamIds.append(team.id)
                                    }
                                } label: {
                                    teamSelectionRow(team: team, isSelected: tier2TeamIds.contains(team.id), label: "Day 2")
                                }
                            }

                            if availableForDay2.isEmpty {
                                Text("All squads assigned to Day 1")
                                    .font(AztecTheme.sfProBold(size: 14))
                                    .foregroundColor(AztecTheme.hotPink)
                            }

                            Button("NEXT: CONFIRM") {
                                step = 3
                            }
                            .buttonStyle(AztecButtonStyle())

                            Button("BACK") { step = 1 }
                                .buttonStyle(AztecSecondaryButtonStyle(color: AztecTheme.stone))
                        } else {
                            // Step 3: Confirm and create
                            AztecSectionHeader(title: "Confirm Tourney")

                            VStack(alignment: .leading, spacing: 12) {
                                tierSummary(title: "DAY 1 (FRIDAY)", teamIds: tier1TeamIds, color: AztecTheme.neonYellow)
                                tierSummary(title: "DAY 2 (SATURDAY) — \(tier2TeamIds.count) + 3 advancing", teamIds: tier2TeamIds, color: AztecTheme.hotPink)
                                Text("FINALS (SUNDAY)")
                                    .font(AztecTheme.sfProBold(size: 14))
                                    .foregroundColor(AztecTheme.neonYellow)
                                Text("Top 4 finishers from Day 2")
                                    .font(AztecTheme.sfProMedium(size: 12))
                                    .foregroundColor(AztecTheme.dimText)
                            }
                            .padding()
                            .neonCard()

                            Button("START TOURNEY") {
                                Task {
                                    let configs = [
                                        CloudSyncService.TierConfig(
                                            tierNumber: 1,
                                            tierName: "Day 1",
                                            dayLabel: "Friday",
                                            date: day1Date,
                                            teamIds: tier1TeamIds
                                        ),
                                        CloudSyncService.TierConfig(
                                            tierNumber: 2,
                                            tierName: "Day 2",
                                            dayLabel: "Saturday",
                                            date: day2Date,
                                            teamIds: tier2TeamIds
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

                            Button("BACK") { step = 2 }
                                .buttonStyle(AztecSecondaryButtonStyle(color: AztecTheme.stone))
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

    private func teamSelectionRow(team: Team, isSelected: Bool, label: String) -> some View {
        HStack {
            TeamIconView(team: team, size: 28)
            Text(team.name)
                .font(AztecTheme.hobbsFont(size: 28))
                .tracking(AztecTheme.hobbsKerning)
                .foregroundColor(AztecTheme.neonYellow)
            Spacer()
            if isSelected {
                Text(label)
                    .font(AztecTheme.sfProBold(size: 10))
                    .foregroundColor(AztecTheme.hotPink)
            }
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? AztecTheme.neonYellow : AztecTheme.stone)
                .shadow(color: isSelected ? AztecTheme.neonYellow.opacity(0.4) : .clear, radius: 3)
        }
        .padding(14)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? AztecTheme.hotPink : AztecTheme.hotPink.opacity(0.3),
                    lineWidth: 2.25
                )
        )
    }

    private func tierSummary(title: String, teamIds: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AztecTheme.sfProBold(size: 14))
                .foregroundColor(color)
            if teamIds.isEmpty {
                Text("No teams assigned yet")
                    .font(AztecTheme.sfProMedium(size: 12))
                    .foregroundColor(AztecTheme.dimText)
            } else {
                ForEach(teamIds, id: \.self) { id in
                    if let team = cloudService.team(for: id) {
                        Text("  \(team.name)")
                            .font(AztecTheme.sfProMedium(size: 12))
                            .foregroundColor(AztecTheme.lightText)
                    }
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
