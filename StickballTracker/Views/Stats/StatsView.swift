import SwiftUI

struct StatsView: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @State private var sortBy: StatSort = .dongs
    @State private var filterTeamId: String?

    enum StatSort: String, CaseIterable {
        case dongs = "Dongs"
        case salamies = "Salamies"
        case doublePlays = "Dbl Plays"
        case drops = "Drops"

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
            case .dongs:
                return p1.stats.dongs > p2.stats.dongs
            case .salamies:
                return p1.stats.salamies > p2.stats.salamies
            case .doublePlays:
                return p1.stats.doublePlays > p2.stats.doublePlays
            case .drops:
                return p1.stats.drops > p2.stats.drops
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

                // Team aggregated stats
                AztecSectionHeader(title: "Team Stats", color: AztecTheme.jade)
                    .padding(.horizontal)
                    .padding(.top, 8)

                LazyVStack(spacing: 6) {
                    ForEach(cloudService.teams) { team in
                        TeamAggregatedRow(team: team)
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
            Text("DONG")
                .frame(width: 42, alignment: .trailing)
            Text("SAL")
                .frame(width: 32, alignment: .trailing)
            Text("DP")
                .frame(width: 28, alignment: .trailing)
            Text("DRP")
                .frame(width: 32, alignment: .trailing)
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

            // Dongs
            Text("\(player.stats.dongs)")
                .font(.system(size: 12, weight: highlightStat == .dongs ? .black : .medium, design: .monospaced))
                .foregroundColor(highlightStat == .dongs ? AztecTheme.gold : AztecTheme.lightText)
                .frame(width: 42, alignment: .trailing)

            // Salamies
            Text("\(player.stats.salamies)")
                .font(.system(size: 12, weight: highlightStat == .salamies ? .black : .medium, design: .monospaced))
                .foregroundColor(highlightStat == .salamies ? AztecTheme.jade : AztecTheme.lightText)
                .frame(width: 32, alignment: .trailing)

            // Double Plays
            Text("\(player.stats.doublePlays)")
                .font(.system(size: 12, weight: highlightStat == .doublePlays ? .black : .medium, design: .monospaced))
                .foregroundColor(highlightStat == .doublePlays ? AztecTheme.amber : AztecTheme.lightText)
                .frame(width: 28, alignment: .trailing)

            // Drops
            Text("\(player.stats.drops)")
                .font(.system(size: 12, weight: highlightStat == .drops ? .black : .medium, design: .monospaced))
                .foregroundColor(highlightStat == .drops ? AztecTheme.bloodRed : AztecTheme.lightText)
                .frame(width: 32, alignment: .trailing)
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

struct TeamAggregatedRow: View {
    @EnvironmentObject var cloudService: CloudSyncService
    let team: Team

    var teamPlayers: [Player] {
        cloudService.playersForTeam(team.id)
    }

    var totalDongs: Int { teamPlayers.reduce(0) { $0 + $1.stats.dongs } }
    var totalSalamies: Int { teamPlayers.reduce(0) { $0 + $1.stats.salamies } }
    var totalDoublePlays: Int { teamPlayers.reduce(0) { $0 + $1.stats.doublePlays } }

    var body: some View {
        HStack(spacing: 12) {
            Text(team.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AztecTheme.lightText)

            Spacer()

            HStack(spacing: 16) {
                VStack(spacing: 1) {
                    Text("\(totalDongs)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(AztecTheme.gold)
                    Text("D")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AztecTheme.dimText)
                }

                VStack(spacing: 1) {
                    Text("\(totalSalamies)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(AztecTheme.jade)
                    Text("S")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AztecTheme.dimText)
                }

                VStack(spacing: 1) {
                    Text("\(totalDoublePlays)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(AztecTheme.amber)
                    Text("DP")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AztecTheme.dimText)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AztecTheme.darkStone)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
