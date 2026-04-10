import SwiftUI

/// Game entry sheet for recording scores and individual player stats during a game.
struct GameEntrySheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss

    let tierIndex: Int
    let game: TournamentGame

    @State private var team1Score: Int = 0
    @State private var team2Score: Int = 0
    @State private var playerStats: [String: EditablePlayerStats] = [:]
    @State private var currentInning: Int = 1
    @State private var showConfirm = false

    var isCompleted: Bool { game.status == .completed }

    var team1: Team? {
        game.team1Id.flatMap { cloudService.team(for: $0) }
    }

    var team2: Team? {
        game.team2Id.flatMap { cloudService.team(for: $0) }
    }

    var team1Players: [Player] {
        guard let id = game.team1Id else { return [] }
        return cloudService.playersForTeam(id)
    }

    var team2Players: [Player] {
        guard let id = game.team2Id else { return [] }
        return cloudService.playersForTeam(id)
    }

    private var bracketLabel: String {
        switch game.bracketSide {
        case .winners: return "WINNERS BRACKET"
        case .losers: return "LOSERS BRACKET"
        case .championship: return "CHAMPIONSHIP"
        case .ifNecessary: return "IF NECESSARY"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Game header
                        VStack(spacing: 4) {
                            Text("GAME \(game.gameNumber)")
                                .font(AztecTheme.sfProBold(size: 14))
                                .tracking(3)
                                .foregroundColor(AztecTheme.hotPink)
                                .shadow(color: AztecTheme.hotPink.opacity(0.4), radius: 3)

                            Text(bracketLabel)
                                .font(AztecTheme.sfProBold(size: 12))
                                .foregroundColor(AztecTheme.neonYellow)
                        }

                        // Game info: time and field
                        HStack(spacing: 16) {
                            if let time = game.scheduledTime {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(AztecTheme.neonYellow)
                                    Text(time.formatted(.dateTime.hour().minute()))
                                        .font(AztecTheme.sfProBold(size: 14))
                                        .foregroundColor(AztecTheme.neonYellow)
                                }
                            }
                            if let field = game.field {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(AztecTheme.hotPink)
                                    Text(field)
                                        .font(AztecTheme.sfProBold(size: 14))
                                        .foregroundColor(AztecTheme.neonYellow)
                                }
                            }
                            Spacer()
                        }

                        // Score display with manual +/- buttons
                        HStack(spacing: 0) {
                            // Team 1 score
                            VStack(spacing: 8) {
                                if let icon = team1?.iconName {
                                    Image(icon)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 48, height: 48)
                                        .shadow(color: AztecTheme.hotPink.opacity(0.6), radius: 15)
                                }
                                formattedTeamName(team1?.name ?? "Team 1", color: AztecTheme.neonYellow)

                                Text("\(team1Score)")
                                    .font(.system(size: 40, weight: .black, design: .monospaced))
                                    .foregroundColor(AztecTheme.neonYellow)
                                    .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 6)

                                if !isCompleted {
                                    HStack(spacing: 12) {
                                        Button {
                                            if team1Score > 0 { team1Score -= 1 }
                                            syncScores()
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 28))
                                                .foregroundColor(AztecTheme.hotPink)
                                        }

                                        Button {
                                            team1Score += 1
                                            syncScores()
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 28))
                                                .foregroundColor(AztecTheme.neonYellow)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Text("VS")
                                .font(AztecTheme.hobbsFont(size: 82))
                                .tracking(AztecTheme.hobbsKerning)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AztecTheme.neonYellow, AztecTheme.hotPink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 6)
                                .shadow(color: AztecTheme.hotPink.opacity(0.3), radius: 6)
                                .padding(.horizontal, 8)

                            // Team 2 score
                            VStack(spacing: 8) {
                                if let icon = team2?.iconName {
                                    Image(icon)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 48, height: 48)
                                        .shadow(color: AztecTheme.hotPink.opacity(0.6), radius: 15)
                                }
                                formattedTeamName(team2?.name ?? "Team 2", color: AztecTheme.hotPink)

                                Text("\(team2Score)")
                                    .font(.system(size: 40, weight: .black, design: .monospaced))
                                    .foregroundColor(AztecTheme.neonYellow)
                                    .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 6)

                                if !isCompleted {
                                    HStack(spacing: 12) {
                                        Button {
                                            if team2Score > 0 { team2Score -= 1 }
                                            syncScores()
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 28))
                                                .foregroundColor(AztecTheme.hotPink)
                                        }

                                        Button {
                                            team2Score += 1
                                            syncScores()
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 28))
                                                .foregroundColor(AztecTheme.neonYellow)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .aztecCard(highlight: AztecTheme.hotPink)

                        // Inning tracker
                        if !isCompleted {
                            VStack(spacing: 6) {
                                Text("INNING")
                                    .font(AztecTheme.sfProBold(size: 11))
                                    .tracking(2)
                                    .foregroundColor(AztecTheme.hotPink)

                                HStack(spacing: 16) {
                                    Button {
                                        if currentInning > 1 { currentInning -= 1 }
                                        Task { await cloudService.updateGameInning(tierIndex: tierIndex, gameId: game.id, inning: currentInning) }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(AztecTheme.hotPink)
                                    }

                                    Text("\(currentInning)")
                                        .font(.system(size: 32, weight: .black, design: .monospaced))
                                        .foregroundColor(AztecTheme.neonYellow)
                                        .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 4)

                                    Button {
                                        currentInning += 1
                                        Task { await cloudService.updateGameInning(tierIndex: tierIndex, gameId: game.id, inning: currentInning) }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(AztecTheme.neonYellow)
                                    }
                                }
                            }
                            .padding(12)
                            .neonCard()
                        }

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

                            if isCompleted {
                                ForEach(team1Players) { player in
                                    ReadOnlyStatRow(playerName: player.name, stats: completedStats(for: player.id))
                                }
                            } else {
                                ForEach(team1Players) { player in
                                    QuickStatEntry(
                                        playerName: player.name,
                                        stats: binding(for: player.id)
                                    )
                                }
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

                            if isCompleted {
                                ForEach(team2Players) { player in
                                    ReadOnlyStatRow(playerName: player.name, stats: completedStats(for: player.id))
                                }
                            } else {
                                ForEach(team2Players) { player in
                                    QuickStatEntry(
                                        playerName: player.name,
                                        stats: binding(for: player.id)
                                    )
                                }
                            }
                        }

                        // Submit (only for non-completed games)
                        if !isCompleted {
                            Button("RECORD GAME") {
                                showConfirm = true
                            }
                            .buttonStyle(AztecButtonStyle())
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isCompleted ? "Close" : "Go Back") { dismiss() }
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
                if isCompleted {
                    team1Score = game.team1Score
                    team2Score = game.team2Score
                } else {
                    initializePlayerStats()
                    if let inning = game.currentInning {
                        currentInning = inning
                    }
                }
            }
        }
    }

    private func binding(for playerId: String) -> Binding<EditablePlayerStats> {
        Binding(
            get: { playerStats[playerId] ?? EditablePlayerStats() },
            set: { playerStats[playerId] = $0 }
        )
    }

    private func completedStats(for playerId: String) -> EditablePlayerStats {
        if let stats = game.playerGameStats.first(where: { $0.playerId == playerId }) {
            return EditablePlayerStats(dongs: stats.dongs, drops: stats.drops, doublePlays: stats.doublePlays, salamies: stats.salamies)
        }
        return EditablePlayerStats()
    }

    private func initializePlayerStats() {
        for player in team1Players + team2Players {
            if playerStats[player.id] == nil {
                playerStats[player.id] = EditablePlayerStats()
            }
        }
    }

    private func syncScores() {
        Task {
            await cloudService.updateGameScores(
                tierIndex: tierIndex,
                gameId: game.id,
                team1Score: team1Score,
                team2Score: team2Score
            )
        }
    }

    @ViewBuilder
    private func formattedTeamName(_ name: String, color: Color) -> some View {
        let lines = Self.splitTeamName(name)
        VStack(spacing: 0) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(AztecTheme.hobbsFont(size: 66))
                    .tracking(AztecTheme.hobbsKerning)
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.5), radius: 4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
            }
        }
    }

    private static func splitTeamName(_ name: String) -> [String] {
        // "Mothership JV Reds" → ["Mothership", "JV Reds"]
        // "Mothership JV Blacks" → ["Mothership", "JV Blacks"]
        // "No Mames Wey Jovenes" → ["No Mames Wey", "Jovenes"]
        // "No Mames Wey Viejos" → ["No Mames Wey", "Viejos"]
        if name.hasPrefix("Mothership JV") {
            return ["Mothership", String(name.dropFirst("Mothership ".count))]
        }
        if name.hasPrefix("No Mames Wey") && name.count > "No Mames Wey".count {
            return ["No Mames Wey", String(name.dropFirst("No Mames Wey ".count))]
        }
        return [name]
    }

    private func submitGame() {
        let gameStats = playerStats.map { playerId, stats -> PlayerGameStats in
            var gs = PlayerGameStats(playerId: playerId)
            gs.dongs = stats.dongs
            gs.drops = stats.drops
            gs.doublePlays = stats.doublePlays
            gs.salamies = stats.salamies
            return gs
        }

        Task {
            await cloudService.recordGameResult(
                tierIndex: tierIndex,
                gameId: game.id,
                team1Score: team1Score,
                team2Score: team2Score,
                field: game.field,
                gameDate: game.scheduledTime,
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
}

/// Read-only stat display for completed games
struct ReadOnlyStatRow: View {
    let playerName: String
    let stats: EditablePlayerStats

    var body: some View {
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
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AztecTheme.hotPink.opacity(0.3), lineWidth: 2.25)
        )
    }
}

/// Quick stat entry row for a single player.
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
                    StatStepperRow(label: "Dongs", value: $stats.dongs, color: AztecTheme.neonYellow)
                    StatStepperRow(label: "Salamies", value: $stats.salamies, color: AztecTheme.neonYellow)
                    StatStepperRow(label: "Dbl Plays", value: $stats.doublePlays, color: AztecTheme.hotPink)
                    StatStepperRow(label: "Drops", value: $stats.drops, color: AztecTheme.hotPink)
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
