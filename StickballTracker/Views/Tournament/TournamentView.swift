import SwiftUI

struct TournamentView: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @State private var showCreateTournament = false
    @State private var selectedMatchup: MatchupSelection?

    struct MatchupSelection: Identifiable {
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
                        VStack(spacing: 8) {
                            AztecSectionHeader(
                                title: round.roundName,
                                color: roundIndex == tournament.bracket.count - 1
                                    ? AztecTheme.neonYellow
                                    : AztecTheme.hotPink,
                                shapeIndex: roundIndex
                            )
                            .padding(.horizontal)

                            ForEach(Array(round.matchups.enumerated()), id: \.element.id) { matchupIndex, matchup in
                                MatchupCard(
                                    matchup: matchup,
                                    roundIndex: roundIndex,
                                    matchupIndex: matchupIndex
                                )
                                .onTapGesture {
                                    if matchup.team1Id != nil && matchup.team2Id != nil
                                        && matchup.status != .completed {
                                        selectedMatchup = MatchupSelection(
                                            roundIndex: roundIndex,
                                            matchupIndex: matchupIndex,
                                            matchup: matchup
                                        )
                                    }
                                }
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
                                .font(.system(size: 48)).italic()
                                .foregroundColor(AztecTheme.neonYellow)
                                .shadow(color: AztecTheme.neonYellow.opacity(0.5), radius: 8)
                                .shadow(color: AztecTheme.neonYellow.opacity(0.2), radius: 16)
                        }

                        Text("NO ACTIVE TOURNEY")
                            .font(AztecTheme.hobbsFont(size: 32))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundColor(AztecTheme.dimText)

                        Text("Create a tourney to set up brackets\nand start tracking games.")
                            .font(AztecTheme.typewriter(size: 14))
                            .foregroundColor(AztecTheme.dimText)
                            .multilineTextAlignment(.center)

                        if cloudService.teams.count >= 2 {
                            Button("CREATE TOURNEY") {
                                showCreateTournament = true
                            }
                            .buttonStyle(AztecButtonStyle())
                        } else {
                            Text("Add at least 2 squads to create a tourney")
                                .font(AztecTheme.typewriter(size: 12))
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
            }

            Image(systemName: "trophy.fill")
                .font(.system(size: 32)).italic()
                .foregroundColor(AztecTheme.neonYellow)
                .shadow(color: AztecTheme.neonYellow.opacity(0.7), radius: 6)
                .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 12)

            Text("CHAMPION")
                .font(AztecTheme.hobbsFont(size: 24))
                .foregroundColor(AztecTheme.hotPink)
                .shadow(color: AztecTheme.hotPink.opacity(0.5), radius: 4)

            Text(teamName.uppercased())
                .font(AztecTheme.hobbsFont(size: 44))
                .foregroundColor(AztecTheme.neonYellow)
                .shadow(color: AztecTheme.neonYellow.opacity(0.5), radius: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .neonCard(border: AztecTheme.neonYellow)
    }
}

// MARK: - Matchup Card (Option 1 Reference Design)

struct MatchupCard: View {
    @EnvironmentObject var cloudService: CloudSyncService
    let matchup: Matchup
    let roundIndex: Int
    let matchupIndex: Int

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
        VStack(spacing: 0) {
            // Team names row
            HStack(alignment: .center) {
                // Team 1
                HStack(spacing: 8) {
                    if let team = team1 {
                        TeamIconView(team: team, size: 28)
                        Text(team.name.uppercased())
                            .font(AztecTheme.hobbsFont(size: 22))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundColor(team1IsWinner ? AztecTheme.neonYellow : .white)
                            .shadow(color: team1IsWinner ? AztecTheme.neonYellow.opacity(0.6) : .clear, radius: 4)
                    } else {
                        Text("TBD")
                            .font(AztecTheme.hobbsFont(size: 22))
                            .foregroundColor(AztecTheme.dimText)
                    }
                }

                Spacer()

                // Team 2
                HStack(spacing: 8) {
                    if let team = team2 {
                        Text(team.name.uppercased())
                            .font(AztecTheme.hobbsFont(size: 22))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundColor(team2IsWinner ? AztecTheme.neonYellow : .white)
                            .shadow(color: team2IsWinner ? AztecTheme.neonYellow.opacity(0.6) : .clear, radius: 4)
                        TeamIconView(team: team, size: 28)
                    } else {
                        Text("TBD")
                            .font(AztecTheme.hobbsFont(size: 22))
                            .foregroundColor(AztecTheme.dimText)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // VS with neon glow
            Text("VS")
                .font(AztecTheme.hobbsFont(size: 28))
                .foregroundColor(AztecTheme.neonYellow)
                .shadow(color: AztecTheme.neonYellow.opacity(0.8), radius: 4)
                .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 8)
                .shadow(color: AztecTheme.neonYellow.opacity(0.2), radius: 14)
                .padding(.bottom, 8)

            // Yellow divider
            Rectangle()
                .fill(AztecTheme.neonYellow.opacity(0.5))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 2)

            // Game score rows
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { gameIdx in
                    if gameIdx < matchup.games.count {
                        let game = matchup.games[gameIdx]
                        GameScoreRow(
                            gameNumber: gameIdx + 1,
                            team1Score: game.team1Score,
                            team2Score: game.team2Score,
                            isCompleted: game.status == .completed,
                            gameDate: game.gameDate
                        )
                    } else if matchup.status != .completed {
                        GameScoreRow(
                            gameNumber: gameIdx + 1,
                            team1Score: nil,
                            team2Score: nil,
                            isCompleted: false,
                            gameDate: nil
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Schedule info
            if matchup.scheduledDate != nil || matchup.scheduledField != nil {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                HStack(spacing: 6) {
                    if let date = matchup.scheduledDate {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 9, weight: .bold)).italic()
                            .foregroundColor(AztecTheme.jade)
                        Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                            .font(AztecTheme.typewriter(size: 10))
                            .foregroundColor(AztecTheme.dimText)
                    }

                    if matchup.scheduledDate != nil && matchup.scheduledField != nil {
                        Text("·")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AztecTheme.stone)
                    }

                    if let field = matchup.scheduledField {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 9, weight: .bold)).italic()
                            .foregroundColor(AztecTheme.hotPink)
                        Text(field)
                            .font(AztecTheme.typewriter(size: 10))
                            .foregroundColor(AztecTheme.dimText)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }

            // Series status
            if matchup.status == .completed {
                Text("FINAL")
                    .font(AztecTheme.impact(size: 10))
                    .tracking(3)
                    .foregroundColor(AztecTheme.neonYellow)
                    .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 4)
                    .padding(.bottom, 12)
            } else if matchup.status == .inProgress {
                Text("SERIES: \(matchup.seriesDescription)")
                    .font(AztecTheme.impact(size: 9))
                    .tracking(2)
                    .foregroundColor(AztecTheme.hotPink)
                    .shadow(color: AztecTheme.hotPink.opacity(0.4), radius: 3)
                    .padding(.bottom, 12)
            } else {
                Spacer().frame(height: 8)
            }
        }
        .neonCard()
    }
}

// MARK: - Game Score Row

struct GameScoreRow: View {
    let gameNumber: Int
    let team1Score: Int?
    let team2Score: Int?
    let isCompleted: Bool
    let gameDate: Date?

    private var team1Won: Bool {
        guard let s1 = team1Score, let s2 = team2Score, isCompleted else { return false }
        return s1 > s2
    }

    private var team2Won: Bool {
        guard let s1 = team1Score, let s2 = team2Score, isCompleted else { return false }
        return s2 > s1
    }

    var body: some View {
        HStack {
            Text("G\(gameNumber)")
                .font(AztecTheme.impact(size: 9))
                .foregroundColor(AztecTheme.dimText)
                .frame(width: 24, alignment: .leading)

            Spacer()

            if let s1 = team1Score, let s2 = team2Score {
                Text("\(s1)")
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                    .italic()
                    .foregroundColor(team1Won ? AztecTheme.neonYellow : AztecTheme.dimText)
                    .shadow(color: team1Won ? AztecTheme.neonYellow.opacity(0.4) : .clear, radius: 3)

                Text("—")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AztecTheme.stone)
                    .padding(.horizontal, 8)

                Text("\(s2)")
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                    .italic()
                    .foregroundColor(team2Won ? AztecTheme.neonYellow : AztecTheme.dimText)
                    .shadow(color: team2Won ? AztecTheme.neonYellow.opacity(0.4) : .clear, radius: 3)
            } else {
                Text("·")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AztecTheme.stone)
                    .padding(.horizontal, 4)
                Text("—")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.15))
                    .padding(.horizontal, 8)
                Text("·")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AztecTheme.stone)
                    .padding(.horizontal, 4)
            }

            Spacer()

            if let date = gameDate {
                Text(date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(AztecTheme.typewriter(size: 8))
                    .foregroundColor(AztecTheme.stone)
                    .frame(width: 40, alignment: .trailing)
            } else {
                Spacer().frame(width: 40)
            }
        }
        .padding(.vertical, 2)
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
                            AztecSectionHeader(title: "G Four Setup", shapeIndex: 0)

                            AztecSectionHeader(title: "Select Squads (\(selectedTeamIds.count))", color: AztecTheme.jade, shapeIndex: 1)

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
                                            .foregroundColor(AztecTheme.lightText)

                                        Spacer()

                                        Text("\(cloudService.playersForTeam(team.id).count) ballers")
                                            .font(AztecTheme.typewriter(size: 12))
                                            .foregroundColor(AztecTheme.dimText)

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
                                    .background(
                                        selectedTeamIds.contains(team.id)
                                            ? AztecTheme.hotPink.opacity(0.08)
                                            : AztecTheme.darkStone
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                selectedTeamIds.contains(team.id)
                                                    ? AztecTheme.hotPink.opacity(0.4)
                                                    : Color.clear,
                                                lineWidth: 1
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
                                    .font(AztecTheme.typewriter(size: 12))
                                    .foregroundColor(AztecTheme.hotPink)
                            } else {
                                Text("Select at least 2 squads")
                                    .font(AztecTheme.typewriter(size: 12))
                                    .foregroundColor(AztecTheme.hotPink)
                            }
                        } else {
                            // Step 2: Arrange matchups & schedule
                            AztecSectionHeader(title: "First Round Matchups", shapeIndex: 2)

                            Text("Set up who plays whom, and schedule each matchup for the weekend.")
                                .font(AztecTheme.typewriter(size: 13))
                                .foregroundColor(AztecTheme.dimText)
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
                        .foregroundColor(AztecTheme.neonYellow)
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
                .font(AztecTheme.jazzFont(size: 10))
                .tracking(2)
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
                            .foregroundColor(AztecTheme.lightText)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold)).italic()
                            .foregroundColor(AztecTheme.stone)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AztecTheme.hotPink.opacity(0.3), lineWidth: 1)
                    )
                }

                Text("VS")
                    .font(AztecTheme.hobbsFont(size: 22))
                    .foregroundColor(AztecTheme.neonYellow)
                    .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 3)
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
                            .foregroundColor(AztecTheme.lightText)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold)).italic()
                            .foregroundColor(AztecTheme.stone)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AztecTheme.hotPink.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // Schedule section
            VStack(spacing: 8) {
                // Date & Time
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12, weight: .bold)).italic()
                        .foregroundColor(AztecTheme.jade)
                        .frame(width: 20)

                    if let date = setup.scheduledDate {
                        Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                            .font(AztecTheme.typewriter(size: 13))
                            .foregroundColor(AztecTheme.lightText)
                    } else {
                        Text("No time set")
                            .font(AztecTheme.typewriter(size: 13))
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
                            .font(.system(size: 10, weight: .heavy)).italic()
                            .tracking(1)
                            .foregroundColor(AztecTheme.jade)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AztecTheme.jade.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    if setup.scheduledDate != nil {
                        Button {
                            setup.scheduledDate = nil
                            showDatePicker = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold)).italic()
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
                        .font(.system(size: 12, weight: .bold)).italic()
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
                                .font(AztecTheme.typewriter(size: 13))
                                .foregroundColor(
                                    setup.scheduledField != nil
                                        ? AztecTheme.lightText
                                        : AztecTheme.stone
                                )
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold)).italic()
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
