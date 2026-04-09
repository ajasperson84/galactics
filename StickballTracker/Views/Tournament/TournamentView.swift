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

                    switch viewMode {
                    case .schedule:
                        ScheduleView(tier: tier, tierIndex: tierIdx) { game in
                            selectedGame = GameSelection(tierIndex: tierIdx, game: game)
                        }
                    case .bracket:
                        BracketView(tier: tier, tierIndex: tierIdx) { game in
                            selectedGame = GameSelection(tierIndex: tierIdx, game: game)
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
            GameEntrySheet(tierIndex: selection.tierIndex, game: selection.game)
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

                            Text("Select squads that enter on Day 2.\nDay 1 winners will also advance here.")
                                .font(AztecTheme.sfProMedium(size: 14))
                                .foregroundColor(AztecTheme.hotPink)
                                .multilineTextAlignment(.center)

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
                                tierSummary(title: "DAY 1 - ROUND 1", teamIds: tier1TeamIds, color: AztecTheme.neonYellow)
                                tierSummary(title: "DAY 2 - ROUND 2", teamIds: tier2TeamIds, color: AztecTheme.hotPink)
                                Text("DAY 3 - CHAMPIONSHIP")
                                    .font(AztecTheme.sfProBold(size: 14))
                                    .foregroundColor(AztecTheme.neonYellow)
                                Text("Top finishers from Day 2")
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
                                            tierName: "Round 1",
                                            dayLabel: "Friday",
                                            date: day1Date,
                                            teamIds: tier1TeamIds
                                        ),
                                        CloudSyncService.TierConfig(
                                            tierNumber: 2,
                                            tierName: "Round 2",
                                            dayLabel: "Saturday",
                                            date: day2Date,
                                            teamIds: tier2TeamIds
                                        ),
                                        CloudSyncService.TierConfig(
                                            tierNumber: 3,
                                            tierName: "Championship",
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
