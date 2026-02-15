import SwiftUI

/// Quick game entry sheet for recording scores and individual player stats during a matchup.
/// Designed for fast data entry during live tournament play.
struct GameEntrySheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss

    let roundIndex: Int
    let matchupIndex: Int
    let matchup: Matchup

    @State private var currentGameIndex: Int = 0
    @State private var team1Score: Int = 0
    @State private var team2Score: Int = 0
    @State private var playerStats: [String: EditablePlayerStats] = [:]
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
                AztecTheme.obsidian.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Game header
                        VStack(spacing: 4) {
                            Text("GAME \(nextGameNumber) OF 3")
                                .font(.system(size: 12, weight: .heavy))
                                .tracking(3)
                                .foregroundColor(AztecTheme.amber)

                            Text("Series: \(matchup.seriesDescription)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AztecTheme.dimText)
                        }

                        // Score entry
                        HStack(spacing: 0) {
                            // Team 1
                            VStack(spacing: 8) {
                                Text(team1?.name ?? "Team 1")
                                    .font(.system(size: 14, weight: .heavy))
                                    .tracking(1)
                                    .foregroundColor(AztecTheme.lightText)
                                    .lineLimit(1)

                                ScoreCounter(score: $team1Score)
                            }
                            .frame(maxWidth: .infinity)

                            Text("VS")
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(AztecTheme.stone)
                                .padding(.horizontal, 8)

                            // Team 2
                            VStack(spacing: 8) {
                                Text(team2?.name ?? "Team 2")
                                    .font(.system(size: 14, weight: .heavy))
                                    .tracking(1)
                                    .foregroundColor(AztecTheme.lightText)
                                    .lineLimit(1)

                                ScoreCounter(score: $team2Score)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .aztecCard(highlight: AztecTheme.jade)

                        // Player stats - Team 1
                        if let team = team1 {
                            AztecSectionHeader(title: "\(team.name) Stats")
                            ForEach(team1Players) { player in
                                QuickStatEntry(
                                    playerName: player.name,
                                    stats: binding(for: player.id)
                                )
                            }
                        }

                        // Player stats - Team 2
                        if let team = team2 {
                            AztecSectionHeader(title: "\(team.name) Stats")
                            ForEach(team2Players) { player in
                                QuickStatEntry(
                                    playerName: player.name,
                                    stats: binding(for: player.id)
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
                        .foregroundColor(AztecTheme.gold)
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
            gs.atBats = stats.atBats
            gs.hits = stats.singles + stats.doubles + stats.triples + stats.homeRuns
            gs.singles = stats.singles
            gs.doubles = stats.doubles
            gs.triples = stats.triples
            gs.homeRuns = stats.homeRuns
            gs.runs = stats.runs
            gs.rbi = stats.rbi
            gs.strikeouts = stats.strikeouts
            gs.walks = stats.walks
            return gs
        }

        Task {
            await cloudService.recordGameResult(
                roundIndex: roundIndex,
                matchupIndex: matchupIndex,
                gameIndex: matchup.games.count,
                team1Score: team1Score,
                team2Score: team2Score,
                playerStats: gameStats
            )
            dismiss()
        }
    }
}

struct EditablePlayerStats {
    var atBats: Int = 0
    var singles: Int = 0
    var doubles: Int = 0
    var triples: Int = 0
    var homeRuns: Int = 0
    var runs: Int = 0
    var rbi: Int = 0
    var strikeouts: Int = 0
    var walks: Int = 0
}

/// Compact score counter with + / - buttons for quick entry.
struct ScoreCounter: View {
    @Binding var score: Int

    var body: some View {
        HStack(spacing: 12) {
            Button {
                if score > 0 { score -= 1 }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AztecTheme.bloodRed)
            }

            Text("\(score)")
                .font(.system(size: 40, weight: .black, design: .monospaced))
                .foregroundColor(AztecTheme.jade)
                .frame(minWidth: 50)

            Button {
                score += 1
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AztecTheme.jade)
            }
        }
    }
}

/// Quick stat entry row for a single player. Uses stepper-style buttons for fast input.
struct QuickStatEntry: View {
    let playerName: String
    @Binding var stats: EditablePlayerStats
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
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AztecTheme.lightText)

                    Spacer()

                    // Quick summary
                    let hits = stats.singles + stats.doubles + stats.triples + stats.homeRuns
                    Text("\(hits)-\(stats.atBats)")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundColor(AztecTheme.jade)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AztecTheme.stone)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            if isExpanded {
                VStack(spacing: 6) {
                    StatStepperRow(label: "AB", value: $stats.atBats)
                    StatStepperRow(label: "1B", value: $stats.singles, color: AztecTheme.jade)
                    StatStepperRow(label: "2B", value: $stats.doubles, color: AztecTheme.jade)
                    StatStepperRow(label: "3B", value: $stats.triples, color: AztecTheme.jade)
                    StatStepperRow(label: "HR", value: $stats.homeRuns, color: AztecTheme.gold)
                    StatStepperRow(label: "R", value: $stats.runs, color: AztecTheme.jade)
                    StatStepperRow(label: "RBI", value: $stats.rbi, color: AztecTheme.jade)
                    StatStepperRow(label: "K", value: $stats.strikeouts, color: AztecTheme.bloodRed)
                    StatStepperRow(label: "BB", value: $stats.walks)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AztecTheme.darkStone)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(AztecTheme.stone.opacity(0.15), lineWidth: 0.5)
        )
    }
}

/// Individual stat stepper with label, value, and +/- buttons.
struct StatStepperRow: View {
    let label: String
    @Binding var value: Int
    var color: Color = AztecTheme.lightText

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .tracking(1)
                .foregroundColor(AztecTheme.dimText)
                .frame(width: 36, alignment: .leading)

            Spacer()

            Button {
                if value > 0 { value -= 1 }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AztecTheme.stone)
                    .frame(width: 32, height: 28)
                    .background(AztecTheme.obsidian)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Text("\(value)")
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 32)

            Button {
                value += 1
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AztecTheme.jade)
                    .frame(width: 32, height: 28)
                    .background(AztecTheme.obsidian)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}
