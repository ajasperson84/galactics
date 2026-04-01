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
                            // Round header — 2x large, yellow, with glow
                            HStack {
                                Text(round.roundName.uppercased())
                                    .font(AztecTheme.hobbsFont(size: 44))
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
            // Team names + VS on same line — doubled size
            HStack(alignment: .center) {
                // Team 1 — yellow
                if let team = team1 {
                    Text(team.name.uppercased())
                        .font(AztecTheme.hobbsFont(size: 44))
                        .tracking(AztecTheme.hobbsKerning)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .foregroundColor(AztecTheme.neonYellow)
                        .shadow(color: AztecTheme.neonYellow.opacity(0.5), radius: 4)
                } else {
                    Text("TBD")
                        .font(AztecTheme.hobbsFont(size: 44))
                        .tracking(AztecTheme.hobbsKerning)
                        .foregroundColor(AztecTheme.dimText)
                }

                // VS inline
                Text("VS")
                    .font(AztecTheme.hobbsFont(size: 28))
                    .tracking(AztecTheme.hobbsKerning)
                    .foregroundColor(AztecTheme.hotPink)
                    .shadow(color: AztecTheme.hotPink.opacity(0.6), radius: 4)
                    .shadow(color: AztecTheme.hotPink.opacity(0.3), radius: 8)
                    .padding(.horizontal, 4)

                // Team 2 — pink
                if let team = team2 {
                    Text(team.name.uppercased())
                        .font(AztecTheme.hobbsFont(size: 44))
                        .tracking(AztecTheme.hobbsKerning)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .foregroundColor(AztecTheme.hotPink)
                        .shadow(color: AztecTheme.hotPink.opacity(0.5), radius: 4)
                } else {
                    Text("TBD")
                        .font(AztecTheme.hobbsFont(size: 44))
                        .tracking(AztecTheme.hobbsKerning)
                        .foregroundColor(AztecTheme.dimText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            // Yellow divider
            Rectangle()
                .fill(AztecTheme.neonYellow.opacity(0.5))
                .frame(height: 1)
                .padding(.horizontal, 12)
                .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 2)

            // Series wins row
            HStack {
                let t1Wins = matchup.games.filter { $0.status == .completed && $0.team1Score > $0.team2Score }.count
                let t2Wins = matchup.games.filter { $0.status == .completed && $0.team2Score > $0.team1Score }.count

                Text("\(t1Wins)")
                    .font(AztecTheme.hobbsFont(size: 48))
                    .tracking(AztecTheme.hobbsKerning)
                    .foregroundColor(AztecTheme.neonYellow)
                    .shadow(color: AztecTheme.neonYellow.opacity(0.5), radius: 4)

                Spacer()

                // Game score pills
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

                Spacer()

                Text("\(t2Wins)")
                    .font(AztecTheme.hobbsFont(size: 48))
                    .tracking(AztecTheme.hobbsKerning)
                    .foregroundColor(AztecTheme.hotPink)
                    .shadow(color: AztecTheme.hotPink.opacity(0.5), radius: 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)

            // Field name (replaces date)
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
                .padding(.bottom, 4)
            }

            // Series status
            if matchup.status == .completed {
                Text("FINAL")
                    .font(AztecTheme.sfProBold(size: 18))
                    .foregroundColor(AztecTheme.neonYellow)
                    .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 4)
                    .padding(.bottom, 8)
            } else if matchup.status == .inProgress {
                Text("SERIES: \(matchup.seriesDescription)")
                    .font(AztecTheme.sfProBold(size: 16))
                    .foregroundColor(AztecTheme.hotPink)
                    .shadow(color: AztecTheme.hotPink.opacity(0.4), radius: 3)
                    .padding(.bottom, 8)
            } else {
                Spacer().frame(height: 4)
            }
        }
        .neonCard()
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
                    .font(AztecTheme.hobbsFont(size: 22))
                    .tracking(AztecTheme.hobbsKerning)
                    .foregroundColor(AztecTheme.hotPink)
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
