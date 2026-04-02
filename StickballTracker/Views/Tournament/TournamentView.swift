import SwiftUI

struct TournamentView: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @State private var showCreateTournament = false
    @State private var selectedMatchup: MatchupSelection?
    @State private var scheduleMatchup: ScheduleSelection?

    struct MatchupSelection: Identifiable {
        let id = UUID()
        let roundIndex: Int
        let matchupIndex: Int
        let matchup: Matchup
    }

    struct ScheduleSelection: Identifiable {
        let id = UUID()
        let roundIndex: Int
        let matchupIndex: Int
        let matchup: Matchup
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
                       let lastRound = tournament.bracket.last,
                       let finalMatchup = lastRound.matchups.first,
                       let winnerId = finalMatchup.winnerId,
                       let champion = cloudService.team(for: winnerId) {
                        ChampionBanner(teamName: champion.name, winnerId: winnerId)
                            .padding(.horizontal)
                    }

                    // Bracket rounds
                    ForEach(Array(tournament.bracket.enumerated()), id: \.element.id) { roundIndex, round in
                        VStack(spacing: 16) {
                            // Round header — 2x large, yellow, with glow
                            HStack {
                                Text(round.roundName.uppercased())
                                    .font(AztecTheme.hobbsFont(size: 48))
                                    .tracking(AztecTheme.hobbsKerning)
                                    .foregroundColor(AztecTheme.neonYellow)
                                    .shadow(color: AztecTheme.neonYellow.opacity(0.6), radius: 6)
                                    .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 12)
                                Spacer()
                            }
                            .padding(.horizontal)

                            ForEach(Array(round.matchups.enumerated()), id: \.element.id) { matchupIndex, matchup in
                                MatchupCard(
                                    matchup: matchup,
                                    roundIndex: roundIndex,
                                    matchupIndex: matchupIndex,
                                    onTapPlay: {
                                        if matchup.team1Id != nil && matchup.team2Id != nil
                                            && matchup.status != .completed {
                                            selectedMatchup = MatchupSelection(
                                                roundIndex: roundIndex,
                                                matchupIndex: matchupIndex,
                                                matchup: matchup
                                            )
                                        }
                                    },
                                    onTapSchedule: {
                                        scheduleMatchup = ScheduleSelection(
                                            roundIndex: roundIndex,
                                            matchupIndex: matchupIndex,
                                            matchup: matchup
                                        )
                                    }
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                } else {
                    // No tournament — show create
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
        .sheet(item: $selectedMatchup) { selection in
            GameEntrySheet(
                roundIndex: selection.roundIndex,
                matchupIndex: selection.matchupIndex,
                matchup: selection.matchup
            )
        }
        .sheet(item: $scheduleMatchup) { selection in
            ScheduleMatchupSheet(
                roundIndex: selection.roundIndex,
                matchupIndex: selection.matchupIndex,
                matchup: selection.matchup
            )
        }
    }
}

// MARK: - Schedule Matchup Sheet

struct ScheduleMatchupSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    let roundIndex: Int
    let matchupIndex: Int
    let matchup: Matchup

    @State private var selectedDate: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 25, hour: 10))!
    @State private var selectedField: StickballField?
    @State private var hasDate: Bool = false

    private var tournamentDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 4, day: 25))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 4, day: 27, hour: 23, minute: 59))!
        return start...end
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    AztecSectionHeader(title: "Schedule Game")

                    // Date & Time
                    Toggle(isOn: $hasDate) {
                        Text("SET DATE & TIME")
                            .font(AztecTheme.sfProBold(size: 14))
                            .foregroundColor(AztecTheme.hotPink)
                    }
                    .tint(AztecTheme.hotPink)

                    if hasDate {
                        DatePicker(
                            "Date & Time",
                            selection: $selectedDate,
                            in: tournamentDateRange,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(AztecTheme.neonYellow)
                        .colorScheme(.dark)
                    }

                    // Field picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("FIELD")
                            .font(AztecTheme.sfProBold(size: 11))
                            .tracking(2)
                            .foregroundColor(AztecTheme.hotPink)

                        Menu {
                            Button("None") { selectedField = nil }
                            ForEach(StickballField.allCases, id: \.self) { field in
                                Button(field.rawValue) { selectedField = field }
                            }
                        } label: {
                            HStack {
                                Text(selectedField?.rawValue ?? "Select Field")
                                    .font(AztecTheme.sfProBold(size: 14))
                                    .foregroundColor(
                                        selectedField != nil
                                            ? AztecTheme.neonYellow
                                            : AztecTheme.hotPink.opacity(0.6)
                                    )
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(AztecTheme.hotPink)
                            }
                            .padding(12)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AztecTheme.hotPink.opacity(0.5), lineWidth: 2.25)
                            )
                        }
                    }

                    Button("SAVE SCHEDULE") {
                        Task {
                            guard var tournament = cloudService.tournament else { return }
                            tournament.bracket[roundIndex].matchups[matchupIndex].scheduledDate = hasDate ? selectedDate : nil
                            tournament.bracket[roundIndex].matchups[matchupIndex].scheduledField = selectedField?.rawValue
                            await cloudService.updateTournament(tournament)
                            dismiss()
                        }
                    }
                    .buttonStyle(AztecButtonStyle())

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .dismissButtonStyle()
                }
            }
            .onAppear {
                if let date = matchup.scheduledDate {
                    selectedDate = date
                    hasDate = true
                }
                if let field = matchup.scheduledField {
                    selectedField = StickballField(rawValue: field)
                }
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

// MARK: - Matchup Card

struct MatchupCard: View {
    @EnvironmentObject var cloudService: CloudSyncService
    let matchup: Matchup
    let roundIndex: Int
    let matchupIndex: Int
    var onTapPlay: (() -> Void)?
    var onTapSchedule: (() -> Void)?

    private var team1: Team? {
        matchup.team1Id.flatMap { cloudService.team(for: $0) }
    }

    private var team2: Team? {
        matchup.team2Id.flatMap { cloudService.team(for: $0) }
    }

    private var team1IsWinner: Bool {
        matchup.winnerId != nil && matchup.winnerId == matchup.team1Id
    }

    private var team2IsWinner: Bool {
        matchup.winnerId != nil && matchup.winnerId == matchup.team2Id
    }

    var body: some View {
        VStack(spacing: 4) {
            // Team names + VS — equal width sides, VS centered
            HStack(alignment: .center, spacing: 0) {
                // Team 1 — yellow with yellow glow
                Group {
                    if let team = team1 {
                        Text(team.name.uppercased())
                            .font(AztecTheme.sfProBold(size: 28))
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                            .foregroundColor(AztecTheme.neonYellow)
                            .shadow(color: AztecTheme.neonYellow.opacity(0.6), radius: 6)
                            .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 12)
                            .shadow(color: team1IsWinner ? AztecTheme.hotPink.opacity(0.8) : .clear, radius: 8)
                    } else {
                        Text("TBD")
                            .font(AztecTheme.sfProBold(size: 28))
                            .foregroundColor(AztecTheme.dimText)
                    }
                }
                .frame(maxWidth: .infinity)

                // VS — centered, Hobbs font, 15% larger, gradient yellow→pink
                Text("VS")
                    .font(AztecTheme.hobbsFont(size: 59))
                    .tracking(AztecTheme.hobbsKerning)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AztecTheme.neonYellow, AztecTheme.hotPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: AztecTheme.hotPink.opacity(0.6), radius: 4)
                    .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 8)
                    .fixedSize()
                    .padding(.horizontal, 4)

                // Team 2 — pink with pink glow
                Group {
                    if let team = team2 {
                        Text(team.name.uppercased())
                            .font(AztecTheme.sfProBold(size: 28))
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                            .foregroundColor(AztecTheme.hotPink)
                            .shadow(color: AztecTheme.hotPink.opacity(0.6), radius: 6)
                            .shadow(color: AztecTheme.hotPink.opacity(0.3), radius: 12)
                            .shadow(color: team2IsWinner ? AztecTheme.neonYellow.opacity(0.8) : .clear, radius: 8)
                    } else {
                        Text("TBD")
                            .font(AztecTheme.sfProBold(size: 28))
                            .foregroundColor(AztecTheme.dimText)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            // Gradient divider yellow→pink — 25% thicker
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AztecTheme.neonYellow.opacity(0.5), AztecTheme.hotPink.opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1.25)
                .padding(.horizontal, 12)

            // Series wins row — centered under team names
            HStack(spacing: 0) {
                let t1Wins = matchup.games.filter { $0.status == .completed && $0.team1Score > $0.team2Score }.count
                let t2Wins = matchup.games.filter { $0.status == .completed && $0.team2Score > $0.team1Score }.count

                Text("\(t1Wins)")
                    .font(AztecTheme.hobbsFont(size: 48))
                    .tracking(AztecTheme.hobbsKerning)
                    .foregroundColor(AztecTheme.neonYellow)
                    .shadow(color: AztecTheme.neonYellow.opacity(0.5), radius: 4)
                    .frame(maxWidth: .infinity)

                // Game score pills in center
                HStack(spacing: 8) {
                    ForEach(0..<matchup.games.count, id: \.self) { gameIdx in
                        let game = matchup.games[gameIdx]
                        HStack(spacing: 4) {
                            Text("\(game.team1Score)")
                                .foregroundColor(AztecTheme.neonYellow)
                            Text("-")
                                .foregroundColor(AztecTheme.hotPink)
                            Text("\(game.team2Score)")
                                .foregroundColor(AztecTheme.hotPink)
                        }
                        .font(AztecTheme.sfProBold(size: 16))
                        .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AztecTheme.hotPink.opacity(0.5), lineWidth: 1.5)
                        )
                    }
                }
                .fixedSize()

                Text("\(t2Wins)")
                    .font(AztecTheme.hobbsFont(size: 48))
                    .tracking(AztecTheme.hobbsKerning)
                    .foregroundColor(AztecTheme.hotPink)
                    .shadow(color: AztecTheme.hotPink.opacity(0.5), radius: 4)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)

            // Day, time, and field info
            VStack(spacing: 2) {
                if let date = matchup.scheduledDate {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AztecTheme.neonYellow)
                        Text(date.formatted(.dateTime.weekday(.wide).hour().minute()))
                            .font(AztecTheme.sfProBold(size: 14))
                            .foregroundColor(AztecTheme.neonYellow)
                            .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 2)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }

                if let field = matchup.scheduledField {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AztecTheme.hotPink)
                        Text(field)
                            .font(AztecTheme.sfProBold(size: 14))
                            .foregroundColor(AztecTheme.neonYellow)
                            .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 2)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 2)

            // Series status + action buttons
            if matchup.status == .completed {
                Text("FINAL")
                    .font(AztecTheme.sfProBold(size: 18))
                    .foregroundColor(AztecTheme.neonYellow)
                    .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 4)
                    .padding(.bottom, 8)
            } else {
                HStack(spacing: 12) {
                    Spacer()

                    // Schedule button — always visible for non-completed matchups
                    Button {
                        onTapSchedule?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 12, weight: .bold))
                            Text(matchup.scheduledDate != nil ? "EDIT" : "SCHEDULE")
                                .font(AztecTheme.sfProBold(size: 11))
                        }
                        .foregroundColor(AztecTheme.neonYellow)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(AztecTheme.neonYellow.opacity(0.6), lineWidth: 1.5)
                        )
                    }

                    // Play game button — only when both teams assigned
                    if matchup.team1Id != nil && matchup.team2Id != nil {
                        Button {
                            onTapPlay?()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text("PLAY")
                                    .font(AztecTheme.sfProBold(size: 11))
                            }
                            .foregroundColor(AztecTheme.hotPink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(AztecTheme.hotPink, lineWidth: 1.5)
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [AztecTheme.neonYellow, AztecTheme.hotPink],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2.25
                )
        )
        .shadow(color: AztecTheme.hotPink.opacity(0.3), radius: 6)
    }
}

// MARK: - Create Tournament Sheet

struct MatchupSetupData: Identifiable {
    let id = UUID()
    var team1Id: String
    var team2Id: String
    var scheduledDate: Date?
    var scheduledField: StickballField?
}

struct CreateTournamentSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    @State private var selectedTeamIds: [String] = []
    @State private var matchupSetups: [MatchupSetupData] = []
    @State private var showMatchupSetup = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if !showMatchupSetup {
                            // Step 1: Team selection
                            AztecSectionHeader(title: "G Four Setup")

                            AztecSectionHeader(title: "Select Squads (\(selectedTeamIds.count))", color: AztecTheme.hotPink)

                            ForEach(cloudService.teams) { team in
                                Button {
                                    if let idx = selectedTeamIds.firstIndex(of: team.id) {
                                        selectedTeamIds.remove(at: idx)
                                    } else {
                                        selectedTeamIds.append(team.id)
                                    }
                                } label: {
                                    HStack {
                                        Text(team.name)
                                            .font(AztecTheme.hobbsFont(size: 28))
                                            .tracking(AztecTheme.hobbsKerning)
                                            .foregroundColor(AztecTheme.neonYellow)

                                        Spacer()

                                        Image(systemName: selectedTeamIds.contains(team.id)
                                              ? "checkmark.circle.fill"
                                              : "circle")
                                            .foregroundColor(
                                                selectedTeamIds.contains(team.id)
                                                    ? AztecTheme.neonYellow
                                                    : AztecTheme.stone
                                            )
                                            .shadow(color: selectedTeamIds.contains(team.id)
                                                    ? AztecTheme.neonYellow.opacity(0.4) : .clear, radius: 3)
                                    }
                                    .padding(14)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                selectedTeamIds.contains(team.id)
                                                    ? AztecTheme.hotPink
                                                    : AztecTheme.hotPink.opacity(0.3),
                                                lineWidth: 2.25
                                            )
                                    )
                                }
                            }

                            let isEven = selectedTeamIds.count >= 2 && selectedTeamIds.count % 2 == 0
                            if isEven {
                                Button("SET UP MATCHUPS") {
                                    initializeMatchups()
                                    showMatchupSetup = true
                                }
                                .buttonStyle(AztecButtonStyle())
                            } else if selectedTeamIds.count >= 2 {
                                Text("Select an even number of squads")
                                    .font(AztecTheme.sfProBold(size: 14))
                                    .foregroundColor(AztecTheme.hotPink)
                            } else {
                                Text("Select at least 2 squads")
                                    .font(AztecTheme.sfProBold(size: 14))
                                    .foregroundColor(AztecTheme.hotPink)
                            }
                        } else {
                            // Step 2: Arrange matchups & schedule
                            AztecSectionHeader(title: "First Round Matchups")

                            Text("Set up who plays whom, and schedule each matchup for the weekend.")
                                .font(AztecTheme.sfProMedium(size: 14))
                                .foregroundColor(AztecTheme.hotPink)
                                .multilineTextAlignment(.center)

                            ForEach(Array(matchupSetups.enumerated()), id: \.element.id) { index, _ in
                                MatchupPairCard(
                                    index: index,
                                    setup: $matchupSetups[index],
                                    availableTeamIds: selectedTeamIds
                                )
                            }

                            Button("START TOURNEY") {
                                Task {
                                    let matchups = matchupSetups.map {
                                        (
                                            $0.team1Id,
                                            $0.team2Id,
                                            $0.scheduledDate,
                                            $0.scheduledField?.rawValue
                                        )
                                    }
                                    await cloudService.createTournament(
                                        name: "G Four",
                                        matchups: matchups
                                    )
                                    dismiss()
                                }
                            }
                            .buttonStyle(AztecButtonStyle())

                            Button("BACK") {
                                showMatchupSetup = false
                            }
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

    private func initializeMatchups() {
        matchupSetups = []
        var ids = selectedTeamIds
        while ids.count >= 2 {
            let t1 = ids.removeFirst()
            let t2 = ids.removeFirst()
            matchupSetups.append(MatchupSetupData(team1Id: t1, team2Id: t2))
        }
    }
}

// MARK: - Matchup Pair Card (Tournament Setup)

struct MatchupPairCard: View {
    @EnvironmentObject var cloudService: CloudSyncService
    let index: Int
    @Binding var setup: MatchupSetupData
    let availableTeamIds: [String]

    @State private var showDatePicker = false

    private var tournamentDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 4, day: 25))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 4, day: 27, hour: 23, minute: 59))!
        return start...end
    }

    private var defaultDate: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 25, hour: 10))!
    }

    private var availableTeams: [Team] {
        availableTeamIds.compactMap { cloudService.team(for: $0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("MATCHUP \(index + 1)")
                .font(AztecTheme.sfProBold(size: 16))
                .foregroundColor(AztecTheme.hotPink)
                .shadow(color: AztecTheme.hotPink.opacity(0.4), radius: 3)
                .padding(.vertical, 8)

            // Team dropdown selectors
            HStack {
                Menu {
                    ForEach(availableTeams) { team in
                        Button(team.name) { setup.team1Id = team.id }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if let team = cloudService.team(for: setup.team1Id) {
                            TeamIconView(team: team, size: 22)
                        }
                        Text(cloudService.team(for: setup.team1Id)?.name ?? "Select")
                            .font(AztecTheme.hobbsFont(size: 18))
                            .tracking(AztecTheme.hobbsKerning)
                            .foregroundColor(AztecTheme.neonYellow)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AztecTheme.stone)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AztecTheme.hotPink.opacity(0.5), lineWidth: 2.25)
                    )
                }

                Text("VS")
                    .font(AztecTheme.hobbsFont(size: 26))
                    .tracking(AztecTheme.hobbsKerning)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AztecTheme.neonYellow, AztecTheme.hotPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: AztecTheme.hotPink.opacity(0.4), radius: 3)
                    .padding(.horizontal, 6)

                Menu {
                    ForEach(availableTeams) { team in
                        Button(team.name) { setup.team2Id = team.id }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if let team = cloudService.team(for: setup.team2Id) {
                            TeamIconView(team: team, size: 22)
                        }
                        Text(cloudService.team(for: setup.team2Id)?.name ?? "Select")
                            .font(AztecTheme.hobbsFont(size: 18))
                            .tracking(AztecTheme.hobbsKerning)
                            .foregroundColor(AztecTheme.hotPink)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AztecTheme.stone)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AztecTheme.hotPink.opacity(0.5), lineWidth: 2.25)
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            Rectangle()
                .fill(AztecTheme.hotPink.opacity(0.3))
                .frame(height: 1)

            // Schedule section
            VStack(spacing: 8) {
                // Date & Time
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AztecTheme.neonYellow)
                        .frame(width: 20)

                    if let date = setup.scheduledDate {
                        Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                            .font(AztecTheme.sfProBold(size: 14))
                            .foregroundColor(AztecTheme.neonYellow)
                    } else {
                        Text("No time set")
                            .font(AztecTheme.sfProMedium(size: 14))
                            .foregroundColor(AztecTheme.stone)
                    }

                    Spacer()

                    Button {
                        if setup.scheduledDate == nil {
                            setup.scheduledDate = defaultDate
                        }
                        showDatePicker.toggle()
                    } label: {
                        Text(setup.scheduledDate == nil ? "SET" : "EDIT")
                            .font(AztecTheme.sfProBold(size: 11))
                            .foregroundColor(AztecTheme.neonYellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(AztecTheme.neonYellow, lineWidth: 1.5)
                            )
                    }

                    if setup.scheduledDate != nil {
                        Button {
                            setup.scheduledDate = nil
                            showDatePicker = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(AztecTheme.stone)
                        }
                    }
                }

                if showDatePicker {
                    DatePicker(
                        "Date & Time",
                        selection: Binding(
                            get: { setup.scheduledDate ?? defaultDate },
                            set: { setup.scheduledDate = $0 }
                        ),
                        in: tournamentDateRange,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(AztecTheme.neonYellow)
                    .colorScheme(.dark)
                }

                // Field / Location
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AztecTheme.hotPink)
                        .frame(width: 20)

                    Menu {
                        Button("None") { setup.scheduledField = nil }
                        ForEach(StickballField.allCases, id: \.self) { field in
                            Button(field.rawValue) { setup.scheduledField = field }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(setup.scheduledField?.rawValue ?? "Select field")
                                .font(AztecTheme.sfProBold(size: 14))
                                .foregroundColor(
                                    setup.scheduledField != nil
                                        ? AztecTheme.neonYellow
                                        : AztecTheme.stone
                                )
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(AztecTheme.stone)
                        }
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .neonCard(border: AztecTheme.hotPink, cornerRadius: 10, glow: 0.6)
    }
}
