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
                                    .font(.system(size: 20, weight: .black))
                                    .tracking(2)
                                    .foregroundColor(AztecTheme.gold)

                                Text(tournament.status.rawValue.uppercased())
                                    .font(.system(size: 11, weight: .heavy))
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

                        Text("NO ACTIVE TOURNAMENT")
                            .font(.system(size: 16, weight: .heavy))
                            .tracking(3)
                            .foregroundColor(AztecTheme.stone)

                        Text("Create a tournament to set up brackets\nand start tracking games.")
                            .font(.system(size: 14))
                            .foregroundColor(AztecTheme.dimText)
                            .multilineTextAlignment(.center)

                        if cloudService.teams.count >= 2 {
                            Button("CREATE TOURNAMENT") {
                                showCreateTournament = true
                            }
                            .buttonStyle(AztecButtonStyle())
                        } else {
                            Text("Add at least 2 teams to create a tournament")
                                .font(.system(size: 12, weight: .medium))
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
                .font(.system(size: 12, weight: .heavy))
                .tracking(4)
                .foregroundColor(AztecTheme.amber)

            Text(teamName.uppercased())
                .font(.system(size: 24, weight: .black))
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
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(AztecTheme.dimText)
                                Text("\(game.team1Score)-\(game.team2Score)")
                                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                    .foregroundColor(AztecTheme.jade)
                            }
                        } else {
                            VStack(spacing: 2) {
                                Text("G\(gameIdx + 1)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(AztecTheme.dimText)
                                Text("--")
                                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                    .foregroundColor(AztecTheme.stone)
                            }
                        }
                    }

                    Spacer()

                    if matchup.status == .completed {
                        Text("FINAL")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(2)
                            .foregroundColor(AztecTheme.gold)
                    } else if matchup.status == .inProgress {
                        Text("LIVE")
                            .font(.system(size: 10, weight: .heavy))
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
                    .font(.system(size: 15, weight: isWinner ? .black : .medium))
                    .foregroundColor(
                        isWinner ? AztecTheme.gold : AztecTheme.lightText
                    )
            } else {
                Text("TBD")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AztecTheme.stone)
                    .italic()
            }

            Spacer()

            if teamId != nil {
                Text("\(wins)")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
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

struct CreateTournamentSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    @State private var tournamentName = ""
    @State private var selectedTeamIds: [String] = []
    @State private var matchupPairs: [(String, String)] = []
    @State private var showMatchupSetup = false

    var body: some View {
        NavigationStack {
            ZStack {
                AztecTheme.obsidian.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if !showMatchupSetup {
                            // Step 1: Name and team selection
                            AztecSectionHeader(title: "Tournament Setup")

                            TextField("Tournament Name", text: $tournamentName)
                                .aztecTextField()

                            AztecSectionHeader(title: "Select Teams (\(selectedTeamIds.count))", color: AztecTheme.jade)

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
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(AztecTheme.lightText)

                                        Spacer()

                                        Text("\(cloudService.playersForTeam(team.id).count) players")
                                            .font(.system(size: 12))
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
                                Text("Select an even number of teams")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AztecTheme.amber)
                            } else {
                                Text("Select at least 2 teams")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AztecTheme.amber)
                            }
                        } else {
                            // Step 2: Arrange matchups
                            AztecSectionHeader(title: "First Round Matchups")

                            Text("Drag teams to rearrange who plays whom in the first round.")
                                .font(.system(size: 13))
                                .foregroundColor(AztecTheme.dimText)
                                .multilineTextAlignment(.center)

                            ForEach(Array(matchupPairs.enumerated()), id: \.offset) { index, pair in
                                MatchupPairCard(
                                    index: index,
                                    team1Id: pair.0,
                                    team2Id: pair.1,
                                    onSwapTeam1: {
                                        swapTeamBetweenMatchups(matchupIndex: index, slot: 0)
                                    },
                                    onSwapTeam2: {
                                        swapTeamBetweenMatchups(matchupIndex: index, slot: 1)
                                    }
                                )
                            }

                            Button("START TOURNAMENT") {
                                guard !tournamentName.trimmingCharacters(in: .whitespaces).isEmpty
                                else { return }
                                Task {
                                    await cloudService.createTournament(
                                        name: tournamentName.trimmingCharacters(in: .whitespaces),
                                        matchups: matchupPairs
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
            .navigationTitle("New Tournament")
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
        matchupPairs = []
        var ids = selectedTeamIds
        while ids.count >= 2 {
            let t1 = ids.removeFirst()
            let t2 = ids.removeFirst()
            matchupPairs.append((t1, t2))
        }
    }

    private func swapTeamBetweenMatchups(matchupIndex: Int, slot: Int) {
        guard matchupPairs.count > 1 else { return }
        let nextMatchup = (matchupIndex + 1) % matchupPairs.count
        if slot == 0 {
            let temp = matchupPairs[matchupIndex].0
            matchupPairs[matchupIndex].0 = matchupPairs[nextMatchup].0
            matchupPairs[nextMatchup].0 = temp
        } else {
            let temp = matchupPairs[matchupIndex].1
            matchupPairs[matchupIndex].1 = matchupPairs[nextMatchup].1
            matchupPairs[nextMatchup].1 = temp
        }
    }
}

struct MatchupPairCard: View {
    @EnvironmentObject var cloudService: CloudSyncService
    let index: Int
    let team1Id: String
    let team2Id: String
    var onSwapTeam1: () -> Void
    var onSwapTeam2: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("MATCHUP \(index + 1)")
                .font(.system(size: 10, weight: .heavy))
                .tracking(2)
                .foregroundColor(AztecTheme.amber)
                .padding(.vertical, 6)

            HStack {
                Button {
                    onSwapTeam1()
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AztecTheme.stone)
                        Text(cloudService.team(for: team1Id)?.name ?? "TBD")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AztecTheme.lightText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AztecTheme.obsidian.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Text("VS")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(AztecTheme.stone)
                    .padding(.horizontal, 6)

                Button {
                    onSwapTeam2()
                } label: {
                    HStack {
                        Text(cloudService.team(for: team2Id)?.name ?? "TBD")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AztecTheme.lightText)
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AztecTheme.stone)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AztecTheme.obsidian.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(AztecTheme.darkStone)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AztecTheme.gold.opacity(0.2), lineWidth: 1)
        )
    }
}
