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
                    // Tournament header
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tournament.name.uppercased())
                                    .font(AztecTheme.impact(size: 20))
                                    .tracking(2)
                                    .foregroundColor(AztecTheme.gold)

                                Text("APRIL 25-27, 2026")
                                    .font(AztecTheme.typewriter(size: 12))
                                    .tracking(1.5)
                                    .foregroundColor(AztecTheme.dimText)

                                Text(tournament.status.rawValue.uppercased())
                                    .font(AztecTheme.impact(size: 11))
                                    .tracking(2)
                                    .foregroundColor(
                                        tournament.status == .completed
                                            ? AztecTheme.jade
                                            : AztecTheme.amber
                                    )
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        (tournament.status == .completed
                                            ? AztecTheme.jade
                                            : AztecTheme.amber
                                        ).opacity(0.15)
                                    )
                                    .clipShape(Capsule())
                            }

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
                    }
                    .padding(.horizontal)

                    // Champion display
                    if tournament.status == .completed,
                       let lastRound = tournament.bracket.last,
                       let finalMatchup = lastRound.matchups.first,
                       let winnerId = finalMatchup.winnerId,
                       let champion = cloudService.team(for: winnerId) {
                        ChampionBanner(teamName: champion.name)
                            .padding(.horizontal)
                    }

                    // Bracket rounds
                    ForEach(Array(tournament.bracket.enumerated()), id: \.element.id) { roundIndex, round in
                        VStack(spacing: 8) {
                            AztecSectionHeader(
                                title: round.roundName,
                                color: roundIndex == tournament.bracket.count - 1
                                    ? AztecTheme.gold
                                    : AztecTheme.jade
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
                    // No tournament - show create
                    VStack(spacing: 24) {
                        Spacer().frame(height: 40)

                        ZStack {
                            Circle()
                                .fill(AztecTheme.gold.opacity(0.08))
                                .frame(width: 120, height: 120)

                            Image(systemName: "trophy.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(AztecTheme.goldGradient)
                                .shadow(color: AztecTheme.gold.opacity(0.3), radius: 12)
                        }

                        Text("NO ACTIVE TOURNEY")
                            .font(AztecTheme.impact(size: 16))
                            .tracking(3)
                            .foregroundColor(AztecTheme.stone)

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
                                .foregroundColor(AztecTheme.amber)
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

struct ChampionBanner: View {
    let teamName: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 32))
                .foregroundStyle(AztecTheme.goldGradient)
                .shadow(color: AztecTheme.gold.opacity(0.5), radius: 8)

            Text("CHAMPION")
                .font(AztecTheme.impact(size: 12))
                .tracking(4)
                .foregroundColor(AztecTheme.amber)

            Text(teamName.uppercased())
                .font(AztecTheme.impact(size: 24))
                .tracking(2)
                .foregroundStyle(AztecTheme.goldGradient)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AztecTheme.gold.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AztecTheme.gold.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: AztecTheme.gold.opacity(0.15), radius: 16)
    }
}

struct MatchupCard: View {
    @EnvironmentObject var cloudService: CloudSyncService
    let matchup: Matchup
    let roundIndex: Int
    let matchupIndex: Int

    var body: some View {
        VStack(spacing: 0) {
            // Team rows
            TeamMatchupRow(
                teamId: matchup.team1Id,
                wins: matchup.team1Wins,
                isWinner: matchup.winnerId == matchup.team1Id,
                isTop: true
            )

            Rectangle()
                .fill(AztecTheme.stone.opacity(0.15))
                .frame(height: 1)

            TeamMatchupRow(
                teamId: matchup.team2Id,
                wins: matchup.team2Wins,
                isWinner: matchup.winnerId == matchup.team2Id,
                isTop: false
            )

            // Schedule info
            if matchup.scheduledDate != nil || matchup.scheduledField != nil {
                Rectangle()
                    .fill(AztecTheme.stone.opacity(0.15))
                    .frame(height: 1)

                HStack(spacing: 6) {
                    if let date = matchup.scheduledDate {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AztecTheme.jade)
                        Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                            .font(AztecTheme.typewriter(size: 11))
                            .foregroundColor(AztecTheme.jade)
                    }

                    if matchup.scheduledDate != nil && matchup.scheduledField != nil {
                        Text("·")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AztecTheme.stone)
                    }

                    if let field = matchup.scheduledField {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AztecTheme.amber)
                        Text(field)
                            .font(AztecTheme.typewriter(size: 11))
                            .foregroundColor(AztecTheme.amber)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            // Series status
            if !matchup.games.isEmpty {
                Rectangle()
                    .fill(AztecTheme.stone.opacity(0.15))
                    .frame(height: 1)

                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { gameIdx in
                        if gameIdx < matchup.games.count {
                            let game = matchup.games[gameIdx]
                            VStack(spacing: 2) {
                                Text("G\(gameIdx + 1)")
                                    .font(AztecTheme.impact(size: 9))
                                    .foregroundColor(AztecTheme.dimText)
                                Text("\(game.team1Score)-\(game.team2Score)")
                                    .font(AztecTheme.typewriterBold(size: 12))
                                    .foregroundColor(AztecTheme.jade)
                                if let date = game.gameDate {
                                    Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                        .font(AztecTheme.typewriter(size: 8))
                                        .foregroundColor(AztecTheme.stone)
                                }
                            }
                        } else {
                            VStack(spacing: 2) {
                                Text("G\(gameIdx + 1)")
                                    .font(AztecTheme.impact(size: 9))
                                    .foregroundColor(AztecTheme.dimText)
                                Text("--")
                                    .font(AztecTheme.typewriterBold(size: 12))
                                    .foregroundColor(AztecTheme.stone)
                            }
                        }
                    }

                    Spacer()

                    if matchup.status == .completed {
                        Text("FINAL")
                            .font(AztecTheme.impact(size: 10))
                            .tracking(2)
                            .foregroundColor(AztecTheme.gold)
                    } else if matchup.status == .inProgress {
                        Text("LIVE")
                            .font(AztecTheme.impact(size: 10))
                            .tracking(2)
                            .foregroundColor(AztecTheme.jade)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .background(AztecTheme.darkStone)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    matchup.status == .completed
                        ? AztecTheme.gold.opacity(0.25)
                        : matchup.status == .inProgress
                            ? AztecTheme.jade.opacity(0.3)
                            : AztecTheme.stone.opacity(0.15),
                    lineWidth: 1
                )
        )
    }
}

struct TeamMatchupRow: View {
    @EnvironmentObject var cloudService: CloudSyncService
    let teamId: String?
    let wins: Int
    let isWinner: Bool
    let isTop: Bool

    var body: some View {
        HStack {
            if let teamId, let team = cloudService.team(for: teamId) {
                Text(team.name)
                    .font(isWinner ? AztecTheme.typewriterBold(size: 15) : AztecTheme.typewriter(size: 15))
                    .foregroundColor(
                        isWinner ? AztecTheme.gold : AztecTheme.lightText
                    )
            } else {
                Text("TBD")
                    .font(AztecTheme.typewriter(size: 15))
                    .foregroundColor(AztecTheme.stone)
                    .italic()
            }

            Spacer()

            if teamId != nil {
                Text("\(wins)")
                    .font(AztecTheme.typewriterBold(size: 20))
                    .foregroundColor(
                        isWinner ? AztecTheme.gold : AztecTheme.dimText
                    )
            }

            if isWinner {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AztecTheme.gold)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isWinner ? AztecTheme.gold.opacity(0.06) : Color.clear)
    }
}

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
                AztecTheme.obsidian.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if !showMatchupSetup {
                            // Step 1: Team selection
                            AztecSectionHeader(title: "G Four Setup")

                            AztecSectionHeader(title: "Select Squads (\(selectedTeamIds.count))", color: AztecTheme.jade)

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
                                            .font(AztecTheme.impact(size: 16))
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
                                                    ? AztecTheme.gold
                                                    : AztecTheme.stone
                                            )
                                    }
                                    .padding(14)
                                    .background(
                                        selectedTeamIds.contains(team.id)
                                            ? AztecTheme.gold.opacity(0.08)
                                            : AztecTheme.darkStone
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(
                                                selectedTeamIds.contains(team.id)
                                                    ? AztecTheme.gold.opacity(0.3)
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
                                    .foregroundColor(AztecTheme.amber)
                            } else {
                                Text("Select at least 2 squads")
                                    .font(AztecTheme.typewriter(size: 12))
                                    .foregroundColor(AztecTheme.amber)
                            }
                        } else {
                            // Step 2: Arrange matchups & schedule
                            AztecSectionHeader(title: "First Round Matchups")

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
                        .foregroundColor(AztecTheme.gold)
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
                .foregroundColor(AztecTheme.amber)
                .padding(.vertical, 6)

            // Team dropdown selectors
            HStack {
                Menu {
                    ForEach(availableTeams) { team in
                        Button(team.name) { setup.team1Id = team.id }
                    }
                } label: {
                    HStack {
                        Text(cloudService.team(for: setup.team1Id)?.name ?? "Select")
                            .font(AztecTheme.jazzFont(size: 14))
                            .foregroundColor(AztecTheme.lightText)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AztecTheme.stone)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(AztecTheme.gold.opacity(0.3), lineWidth: 1)
                    )
                }

                Text("VS")
                    .font(AztecTheme.jazzFont(size: 11))
                    .foregroundColor(AztecTheme.stone)
                    .padding(.horizontal, 6)

                Menu {
                    ForEach(availableTeams) { team in
                        Button(team.name) { setup.team2Id = team.id }
                    }
                } label: {
                    HStack {
                        Text(cloudService.team(for: setup.team2Id)?.name ?? "Select")
                            .font(AztecTheme.jazzFont(size: 14))
                            .foregroundColor(AztecTheme.lightText)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AztecTheme.stone)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(AztecTheme.gold.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            Rectangle()
                .fill(AztecTheme.stone.opacity(0.15))
                .frame(height: 1)

            // Schedule section
            VStack(spacing: 8) {
                // Date & Time
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12, weight: .bold))
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
                            .font(.system(size: 10, weight: .heavy))
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
                    .tint(AztecTheme.gold)
                    .colorScheme(.dark)
                }

                // Field / Location
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AztecTheme.amber)
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
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(AztecTheme.stone)
                        }
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(AztecTheme.darkStone)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AztecTheme.gold.opacity(0.2), lineWidth: 1)
        )
    }
}
