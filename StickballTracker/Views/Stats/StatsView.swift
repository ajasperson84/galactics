import SwiftUI

struct StatsView: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @State private var sortBy: StatSort = .average
    @State private var filterTeamId: String?

    enum StatSort: String, CaseIterable {
        case average = "AVG"
        case homeRuns = "HR"
        case rbi = "RBI"
        case hits = "H"
        case ops = "OPS"

        var label: String { rawValue }
    }

    var filteredPlayers: [Player] {
        var list = cloudService.players
        if let teamId = filterTeamId {
            list = list.filter { $0.teamId == teamId }
        }
        return list.filter { $0.stats.gamesPlayed > 0 }
    }

    var sortedPlayers: [Player] {
        filteredPlayers.sorted { p1, p2 in
            switch sortBy {
            case .average:
                return p1.stats.battingAverage > p2.stats.battingAverage
            case .homeRuns:
                return p1.stats.homeRuns > p2.stats.homeRuns
            case .rbi:
                return p1.stats.rbi > p2.stats.rbi
            case .hits:
                return p1.stats.hits > p2.stats.hits
            case .ops:
                let ops1 = p1.stats.onBasePercentage + p1.stats.sluggingPercentage
                let ops2 = p2.stats.onBasePercentage + p2.stats.sluggingPercentage
                return ops1 > ops2
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Leaderboard header
                AztecSectionHeader(title: "Leaderboards")
                    .padding(.horizontal)

                // Sort options
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(StatSort.allCases, id: \.self) { sort in
                            Button {
                                withAnimation { sortBy = sort }
                            } label: {
                                Text(sort.label)
                                    .font(.system(size: 12, weight: .heavy))
                                    .tracking(1)
                                    .foregroundColor(
                                        sortBy == sort ? AztecTheme.obsidian : AztecTheme.gold
                                    )
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        sortBy == sort
                                            ? AztecTheme.gold
                                            : AztecTheme.gold.opacity(0.1)
                                    )
                                    .clipShape(Capsule())
                            }
                        }

                        Divider()
                            .frame(height: 20)
                            .background(AztecTheme.stone)

                        // Team filter
                        Button {
                            filterTeamId = nil
                        } label: {
                            Text("ALL")
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(1)
                                .foregroundColor(
                                    filterTeamId == nil
                                        ? AztecTheme.obsidian
                                        : AztecTheme.jade
                                )
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    filterTeamId == nil
                                        ? AztecTheme.jade
                                        : AztecTheme.jade.opacity(0.1)
                                )
                                .clipShape(Capsule())
                        }

                        ForEach(cloudService.teams) { team in
                            Button {
                                filterTeamId = team.id
                            } label: {
                                Text(team.name.prefix(6).uppercased())
                                    .font(.system(size: 11, weight: .heavy))
                                    .tracking(1)
                                    .foregroundColor(
                                        filterTeamId == team.id
                                            ? AztecTheme.obsidian
                                            : AztecTheme.jade
                                    )
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(
                                        filterTeamId == team.id
                                            ? AztecTheme.jade
                                            : AztecTheme.jade.opacity(0.1)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Stats table
                if sortedPlayers.isEmpty {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 40)
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 40))
                            .foregroundColor(AztecTheme.stone)
                        Text("No stats recorded yet")
                            .font(.system(size: 14))
                            .foregroundColor(AztecTheme.dimText)
                        Text("Play some games to see leaderboards.")
                            .font(.system(size: 12))
                            .foregroundColor(AztecTheme.stone)
                    }
                } else {
                    // Table header
                    StatsTableHeader()
                        .padding(.horizontal)

                    // Player rows
                    LazyVStack(spacing: 4) {
                        ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                            StatsTableRow(rank: index + 1, player: player, highlightStat: sortBy)
                        }
                    }
                    .padding(.horizontal)
                }

                // Team standings
                AztecSectionHeader(title: "Team Standings", color: AztecTheme.jade)
                    .padding(.horizontal)
                    .padding(.top, 8)

                let sortedTeams = cloudService.teams.sorted { $0.winPercentage > $1.winPercentage }
                LazyVStack(spacing: 6) {
                    ForEach(Array(sortedTeams.enumerated()), id: \.element.id) { index, team in
                        TeamStandingRow(rank: index + 1, team: team)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
}

struct StatsTableHeader: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("#")
                .frame(width: 24, alignment: .center)
            Text("PLAYER")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("GP")
                .frame(width: 30, alignment: .trailing)
            Text("AVG")
                .frame(width: 42, alignment: .trailing)
            Text("HR")
                .frame(width: 28, alignment: .trailing)
            Text("RBI")
                .frame(width: 32, alignment: .trailing)
            Text("H")
                .frame(width: 28, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .heavy))
        .tracking(0.5)
        .foregroundColor(AztecTheme.dimText)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

struct StatsTableRow: View {
    let rank: Int
    let player: Player
    let highlightStat: StatsView.StatSort

    var highlightValue: String {
        switch highlightStat {
        case .average:
            return String(format: ".%03d", Int(player.stats.battingAverage * 1000))
        case .homeRuns:
            return "\(player.stats.homeRuns)"
        case .rbi:
            return "\(player.stats.rbi)"
        case .hits:
            return "\(player.stats.hits)"
        case .ops:
            let ops = player.stats.onBasePercentage + player.stats.sluggingPercentage
            return String(format: ".%03d", Int(ops * 1000))
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            // Rank
            Text("\(rank)")
                .font(.system(size: 12, weight: rank <= 3 ? .black : .bold, design: .monospaced))
                .foregroundColor(
                    rank == 1 ? AztecTheme.gold :
                    rank == 2 ? AztecTheme.lightText :
                    rank == 3 ? AztecTheme.amber :
                    AztecTheme.dimText
                )
                .frame(width: 24, alignment: .center)

            // Name
            Text(player.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AztecTheme.lightText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            // GP
            Text("\(player.stats.gamesPlayed)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(AztecTheme.dimText)
                .frame(width: 30, alignment: .trailing)

            // AVG
            Text(String(format: ".%03d", Int(player.stats.battingAverage * 1000)))
                .font(.system(size: 12, weight: highlightStat == .average ? .black : .medium, design: .monospaced))
                .foregroundColor(highlightStat == .average ? AztecTheme.jade : AztecTheme.lightText)
                .frame(width: 42, alignment: .trailing)

            // HR
            Text("\(player.stats.homeRuns)")
                .font(.system(size: 12, weight: highlightStat == .homeRuns ? .black : .medium, design: .monospaced))
                .foregroundColor(highlightStat == .homeRuns ? AztecTheme.gold : AztecTheme.lightText)
                .frame(width: 28, alignment: .trailing)

            // RBI
            Text("\(player.stats.rbi)")
                .font(.system(size: 12, weight: highlightStat == .rbi ? .black : .medium, design: .monospaced))
                .foregroundColor(highlightStat == .rbi ? AztecTheme.jade : AztecTheme.lightText)
                .frame(width: 32, alignment: .trailing)

            // H
            Text("\(player.stats.hits)")
                .font(.system(size: 12, weight: highlightStat == .hits ? .black : .medium, design: .monospaced))
                .foregroundColor(highlightStat == .hits ? AztecTheme.jade : AztecTheme.lightText)
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            rank <= 3
                ? (rank == 1 ? AztecTheme.gold : AztecTheme.amber).opacity(0.05)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct TeamStandingRow: View {
    let rank: Int
    let team: Team

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(
                    rank == 1 ? AztecTheme.gold : AztecTheme.dimText
                )
                .frame(width: 24)

            Text(team.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AztecTheme.lightText)

            Spacer()

            Text("\(team.wins)-\(team.losses)")
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundColor(AztecTheme.jade)

            if team.wins + team.losses > 0 {
                Text(String(format: ".%03d", Int(team.winPercentage * 1000)))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(AztecTheme.dimText)
                    .frame(width: 42)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            rank == 1 ? AztecTheme.gold.opacity(0.06) : AztecTheme.darkStone
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    rank == 1 ? AztecTheme.gold.opacity(0.25) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}
