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
                                .font(AztecTheme.impact(size: 12))
                                .tracking(3)
                                .foregroundColor(AztecTheme.hotPink)
                                .shadow(color: AztecTheme.hotPink.opacity(0.4), radius: 3)

                            Text("Series: \(matchup.seriesDescription)")
                                .font(AztecTheme.typewriter(size: 14))
                                .foregroundColor(AztecTheme.dimText)
                        }

                        // Field picker
                        VStack(spacing: 6) {
                            Text("FIELD")
                                .font(AztecTheme.impact(size: 11))
                                .tracking(2)
                                .foregroundColor(AztecTheme.dimText)

                            Menu {
                                Button("None") { selectedField = nil }
                                ForEach(StickballField.allCases, id: \.self) { field in
                                    Button(field.rawValue) { selectedField = field }
                                }
                            } label: {
                                HStack {
                                    Text(selectedField?.rawValue ?? "Select Field")
                                        .font(AztecTheme.typewriterBold(size: 14))
                                        .foregroundColor(
                                            selectedField != nil
                                                ? AztecTheme.lightText
                                                : AztecTheme.stone
                                        )
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(AztecTheme.stone)
                                }
                                .padding(12)
                                .background(AztecTheme.darkStone)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AztecTheme.hotPink.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }

                        // Date & time picker
                        VStack(spacing: 6) {
                            Text("DATE & TIME")
                                .font(AztecTheme.impact(size: 11))
                                .tracking(2)
                                .foregroundColor(AztecTheme.dimText)

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
                                            .frame(width: 20, height: 20)
                                    }
                                    Text(team1?.name ?? "Team 1")
                                        .font(AztecTheme.hobbsFont(size: 22))
                                        .foregroundColor(AztecTheme.lightText)
                                        .lineLimit(1)
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
                                            .foregroundColor(AztecTheme.stone)
                                    }

                                    Button {
                                        team1Score += 1
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(AztecTheme.jade)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Text("VS")
                                .font(AztecTheme.hobbsFont(size: 22))
                                .foregroundColor(AztecTheme.neonYellow)
                                .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 3)
                                .padding(.horizontal, 8)

                            // Team 2 score
                            VStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    if let icon = team2?.iconName {
                                        Image(icon)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    }
                                    Text(team2?.name ?? "Team 2")
                                        .font(AztecTheme.hobbsFont(size: 22))
                                        .foregroundColor(AztecTheme.lightText)
                                        .lineLimit(1)
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
                                            .foregroundColor(AztecTheme.stone)
                                    }

                                    Button {
                                        team2Score += 1
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(AztecTheme.jade)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .aztecCard(highlight: AztecTheme.hotPink)

                        // Player stats - Team 1
                        if let team = team1 {
                            AztecSectionHeader(title: "\(team.name) Players", shapeIndex: 0)
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
                            AztecSectionHeader(title: "\(team.name) Players", shapeIndex: 1)
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
            .navigationTitle("Enter Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AztecTheme.neonYellow)
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
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 4, day: 25))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 4, day: 27, hour: 23, minute: 59))!
        return start...end
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
                        .font(AztecTheme.hobbsFont(size: 22))
                        .foregroundColor(AztecTheme.lightText)

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
                                .foregroundColor(AztecTheme.jade)
                        }
                        if stats.doublePlays > 0 {
                            Text("\(stats.doublePlays)DP")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundColor(AztecTheme.hotPink)
                        }
                        if stats.drops > 0 {
                            Text("\(stats.drops)Dr")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundColor(AztecTheme.bloodRed)
                        }
                        if stats.suds > 0 {
                            Text("\(stats.suds)Su")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundColor(AztecTheme.cosmic)
                        }
                        if stats.tacos > 0 {
                            Text("\(stats.tacos)T")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundColor(AztecTheme.tennisGreen)
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AztecTheme.stone)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            if isExpanded {
                VStack(spacing: 6) {
                    StatStepperRow(label: "Dongs", value: $stats.dongs, color: AztecTheme.neonYellow) { delta in
                        onDongChanged(delta)
                    }
                    StatStepperRow(label: "Salamies", value: $stats.salamies, color: AztecTheme.jade) { delta in
                        onSalamiChanged(delta)
                    }
                    StatStepperRow(label: "Dbl Plays", value: $stats.doublePlays, color: AztecTheme.hotPink)
                    StatStepperRow(label: "Drops", value: $stats.drops, color: AztecTheme.bloodRed)
                    StatStepperRow(label: "Suds", value: $stats.suds, color: AztecTheme.cosmic)
                    StatStepperRow(label: "Tacos", value: $stats.tacos, color: AztecTheme.tennisGreen)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AztecTheme.darkStone)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AztecTheme.hotPink.opacity(0.2), lineWidth: 1)
        )
    }
}

/// Individual stat stepper with label, value, and +/- buttons.
struct StatStepperRow: View {
    let label: String
    @Binding var value: Int
    var color: Color = AztecTheme.lightText
    var onChanged: ((Int) -> Void)?

    var body: some View {
        HStack {
            Text(label)
                .font(AztecTheme.impact(size: 12))
                .tracking(0.5)
                .foregroundColor(AztecTheme.dimText)
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
                    .foregroundColor(AztecTheme.stone)
                    .frame(width: 32, height: 28)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
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
                    .foregroundColor(AztecTheme.jade)
                    .frame(width: 32, height: 28)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}
