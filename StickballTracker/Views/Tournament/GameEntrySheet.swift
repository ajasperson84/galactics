import SwiftUI

/// Game entry sheet for recording scores and individual player stats during a matchup.
struct GameEntrySheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss

    let roundIndex: Int
    let matchupIndex: Int
    let matchup: Matchup

    @State private var team1Score: Int = 0
    @State private var team2Score: Int = 0
    @State private var playerStats: [String: EditablePlayerStats] = [:]
    @State private var selectedField: StickballField?
    @State private var gameDate: Date = Date()
    @State private var showConfirm = false

    var team1: Team? {
        matchup.team1Id.flatMap { cloudService.team(for: $0) }
    }

    var team2: Team? {
        matchup.team2Id.flatMap { cloudService.team(for: $0) }
    }

    var team1Players: [Player] {
        guard let id = matchup.team1Id else { return [] }
        return cloudService.playersForTeam(id)
    }

    var team2Players: [Player] {
        guard let id = matchup.team2Id else { return [] }
        return cloudService.playersForTeam(id)
    }

    var nextGameNumber: Int {
        matchup.games.count + 1
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Game header
                        VStack(spacing: 4) {
                            Text("GAME \(nextGameNumber) OF 3")
                                .font(AztecTheme.sfProBold(size: 12))
                                .tracking(3)
                                .foregroundColor(AztecTheme.hotPink)
                                .shadow(color: AztecTheme.hotPink.opacity(0.4), radius: 3)

                            Text("Series: \(matchup.seriesDescription)")
                                .font(AztecTheme.sfProBold(size: 14))
                                .foregroundColor(AztecTheme.neonYellow)
                        }

                        // Field picker
                        VStack(spacing: 6) {
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

                        // Date & time picker
                        VStack(spacing: 6) {
                            Text("DATE & TIME")
                                .font(AztecTheme.sfProBold(size: 11))
                                .tracking(2)
                                .foregroundColor(AztecTheme.hotPink)

                            DatePicker(
                                "Game Date",
                                selection: $gameDate,
                                in: tournamentDateRange,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(AztecTheme.neonYellow)
                            .colorScheme(.dark)
                        }

                        // Score display with manual +/- buttons
                        HStack(spacing: 0) {
                            // Team 1 score
                            VStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    if let icon = team1?.iconName {
                                        Image(icon)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 48, height: 48)
                                            .shadow(color: AztecTheme.hotPink.opacity(0.6), radius: 15)
                                    }
                                    Text(team1?.name ?? "Team 1")
                                        .font(AztecTheme.hobbsFont(size: 53))
                                        .tracking(AztecTheme.hobbsKerning)
                                        .foregroundColor(AztecTheme.neonYellow)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.4)
                                }

                                Text("\(team1Score)")
                                    .font(.system(size: 40, weight: .black, design: .monospaced))
                                    .foregroundColor(AztecTheme.neonYellow)
                                    .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 6)

                                HStack(spacing: 12) {
                                    Button {
                                        if team1Score > 0 { team1Score -= 1 }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(AztecTheme.hotPink)
                                    }

                                    Button {
                                        team1Score += 1
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(AztecTheme.neonYellow)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Text("VS")
                                .font(AztecTheme.hobbsFont(size: 55))
                                .tracking(AztecTheme.hobbsKerning)
                                .foregroundColor(AztecTheme.hotPink)
                                .shadow(color: AztecTheme.hotPink.opacity(0.4), radius: 3)
                                .padding(.horizontal, 8)

                            // Team 2 score
                            VStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    if let icon = team2?.iconName {
                                        Image(icon)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 48, height: 48)
                                            .shadow(color: AztecTheme.hotPink.opacity(0.6), radius: 15)
                                    }
                                    Text(team2?.name ?? "Team 2")
                                        .font(AztecTheme.hobbsFont(size: 53))
                                        .tracking(AztecTheme.hobbsKerning)
                                        .foregroundColor(AztecTheme.hotPink)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.4)
                                }

                                Text("\(team2Score)")
                                    .font(.system(size: 40, weight: .black, design: .monospaced))
                                    .foregroundColor(AztecTheme.neonYellow)
                                    .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 6)

                                HStack(spacing: 12) {
                                    Button {
                                        if team2Score > 0 { team2Score -= 1 }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(AztecTheme.hotPink)
                                    }

                                    Button {
                                        team2Score += 1
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(AztecTheme.neonYellow)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .aztecCard(highlight: AztecTheme.hotPink)

                        // Player stats - Team 1
                        if let team = team1 {
                            HStack {
                                Text("\(team.name) Players".uppercased())
                                    .font(AztecTheme.hobbsFont(size: 48))
                                    .tracking(AztecTheme.hobbsKerning)
                                    .foregroundColor(AztecTheme.neonYellow)
                                    .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 4)
                                Spacer()
                            }
                            ForEach(team1Players) { player in
                                QuickStatEntry(
                                    playerName: player.name,
                                    stats: binding(for: player.id),
                                    onDongChanged: { delta in team1Score = max(0, team1Score + delta) },
                                    onSalamiChanged: { delta in team1Score = max(0, team1Score + (delta * 4)) }
                                )
                            }
                        }

                        // Player stats - Team 2
                        if let team = team2 {
                            HStack {
                                Text("\(team.name) Players".uppercased())
                                    .font(AztecTheme.hobbsFont(size: 48))
                                    .tracking(AztecTheme.hobbsKerning)
                                    .foregroundColor(AztecTheme.hotPink)
                                    .shadow(color: AztecTheme.hotPink.opacity(0.4), radius: 4)
                                Spacer()
                            }
                            ForEach(team2Players) { player in
                                QuickStatEntry(
                                    playerName: player.name,
                                    stats: binding(for: player.id),
                                    onDongChanged: { delta in team2Score = max(0, team2Score + delta) },
                                    onSalamiChanged: { delta in team2Score = max(0, team2Score + (delta * 4)) }
                                )
                            }
                        }

                        // Submit
                        Button("RECORD GAME") {
                            showConfirm = true
                        }
                        .buttonStyle(AztecButtonStyle())
                        .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .dismissButtonStyle()
                }
            }
            .alert("Record Game?", isPresented: $showConfirm) {
                Button("Record", role: .none) {
                    submitGame()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                let t1 = team1?.name ?? "Team 1"
                let t2 = team2?.name ?? "Team 2"
                Text("\(t1) \(team1Score) - \(team2Score) \(t2)")
            }
            .onAppear {
                initializePlayerStats()
            }
        }
    }

    private var tournamentDateRange: ClosedRange<Date> {
        guard let tournament = cloudService.tournament else {
            return Date()...Date()
        }
        return tournament.dateRange
    }

    private func binding(for playerId: String) -> Binding<EditablePlayerStats> {
        Binding(
            get: { playerStats[playerId] ?? EditablePlayerStats() },
            set: { playerStats[playerId] = $0 }
        )
    }

    private func initializePlayerStats() {
        for player in team1Players + team2Players {
            if playerStats[player.id] == nil {
                playerStats[player.id] = EditablePlayerStats()
            }
        }
    }

    private func submitGame() {
        let gameStats = playerStats.map { playerId, stats -> PlayerGameStats in
            var gs = PlayerGameStats(playerId: playerId)
            gs.dongs = stats.dongs
            gs.drops = stats.drops
            gs.doublePlays = stats.doublePlays
            gs.salamies = stats.salamies
            gs.suds = stats.suds
            gs.tacos = stats.tacos
            return gs
        }

        Task {
            await cloudService.recordGameResult(
                roundIndex: roundIndex,
                matchupIndex: matchupIndex,
                gameIndex: matchup.games.count,
                team1Score: team1Score,
                team2Score: team2Score,
                field: selectedField?.rawValue,
                gameDate: gameDate,
                playerStats: gameStats
            )
            dismiss()
        }
    }
}

struct EditablePlayerStats {
    var dongs: Int = 0
    var drops: Int = 0
    var doublePlays: Int = 0
    var salamies: Int = 0
    var suds: Int = 0
    var tacos: Int = 0
}

/// Quick stat entry row for a single player.
struct QuickStatEntry: View {
    let playerName: String
    @Binding var stats: EditablePlayerStats
    var onDongChanged: (Int) -> Void
    var onSalamiChanged: (Int) -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header - tap to expand
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(playerName)
                        .font(AztecTheme.sfProBold(size: 19))
                        .foregroundColor(AztecTheme.neonYellow)

                    Spacer()

                    HStack(spacing: 8) {
                        if stats.dongs > 0 {
                            Text("\(stats.dongs)D")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundColor(AztecTheme.neonYellow)
                        }
                        if stats.salamies > 0 {
                            Text("\(stats.salamies)S")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundColor(AztecTheme.neonYellow)
                        }
                        if stats.doublePlays > 0 {
                            Text("\(stats.doublePlays)DP")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundColor(AztecTheme.hotPink)
                        }
                        if stats.drops > 0 {
                            Text("\(stats.drops)Dr")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundColor(AztecTheme.hotPink)
                        }
                        if stats.suds > 0 {
                            Text("\(stats.suds)Su")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundColor(AztecTheme.neonYellow)
                        }
                        if stats.tacos > 0 {
                            Text("\(stats.tacos)T")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundColor(AztecTheme.neonYellow)
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AztecTheme.hotPink)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            if isExpanded {
                VStack(spacing: 6) {
                    StatStepperRow(label: "Dongs", value: $stats.dongs, color: AztecTheme.neonYellow) { delta in
                        onDongChanged(delta)
                    }
                    StatStepperRow(label: "Salamies", value: $stats.salamies, color: AztecTheme.neonYellow) { delta in
                        onSalamiChanged(delta)
                    }
                    StatStepperRow(label: "Dbl Plays", value: $stats.doublePlays, color: AztecTheme.hotPink)
                    StatStepperRow(label: "Drops", value: $stats.drops, color: AztecTheme.hotPink)
                    StatStepperRow(label: "Suds", value: $stats.suds, color: AztecTheme.neonYellow)
                    StatStepperRow(label: "Tacos", value: $stats.tacos, color: AztecTheme.neonYellow)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AztecTheme.hotPink.opacity(0.4), lineWidth: 2.25)
        )
    }
}

/// Individual stat stepper with label, value, and +/- buttons.
struct StatStepperRow: View {
    let label: String
    @Binding var value: Int
    var color: Color = AztecTheme.neonYellow
    var onChanged: ((Int) -> Void)?

    var body: some View {
        HStack {
            Text(label)
                .font(AztecTheme.sfProBold(size: 12))
                .tracking(0.5)
                .foregroundColor(AztecTheme.hotPink)
                .frame(width: 72, alignment: .leading)

            Spacer()

            Button {
                if value > 0 {
                    value -= 1
                    onChanged?(-1)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AztecTheme.hotPink)
                    .frame(width: 32, height: 28)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(AztecTheme.hotPink.opacity(0.3), lineWidth: 1)
                    )
            }

            Text("\(value)")
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 32)

            Button {
                value += 1
                onChanged?(1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AztecTheme.neonYellow)
                    .frame(width: 32, height: 28)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(AztecTheme.neonYellow.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
}
