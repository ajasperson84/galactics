import SwiftUI

struct StatsView: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @State private var sortBy: StatSort = .dongs

    enum StatSort: String, CaseIterable {
        case dongs = "Dongs"
        case salamies = "Salamies"
        case doublePlays = "Dbl Plays"
        case drops = "Drops"
        case suds = "Suds"
        case tacos = "Tacos"

        var label: String { rawValue }
    }

    var sortedPlayers: [Player] {
        let eligible = cloudService.players.filter { $0.stats.gamesPlayed > 0 }
        let sorted = eligible.sorted { p1, p2 in
            switch sortBy {
            case .dongs:
                return p1.stats.dongs > p2.stats.dongs
            case .salamies:
                return p1.stats.salamies > p2.stats.salamies
            case .doublePlays:
                return p1.stats.doublePlays > p2.stats.doublePlays
            case .drops:
                return p1.stats.drops > p2.stats.drops
            case .suds:
                return p1.stats.suds > p2.stats.suds
            case .tacos:
                return p1.stats.tacos > p2.stats.tacos
            }
        }
        return Array(sorted.prefix(10))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Leaderboard header
                AztecSectionHeader(title: "Top 10 Leaderboard")
                    .padding(.horizontal)

                // Sort options
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(StatSort.allCases, id: \.self) { sort in
                            Button {
                                withAnimation { sortBy = sort }
                            } label: {
                                Text(sort.label)
                                    .font(AztecTheme.impact(size: 12))
                                    .tracking(1)
                                    .foregroundColor(
                                        sortBy == sort ? AztecTheme.ink : AztecTheme.ink
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
                            .font(AztecTheme.typewriter(size: 14))
                            .foregroundColor(AztecTheme.dimText)
                        Text("Play some games to see leaderboards.")
                            .font(AztecTheme.typewriter(size: 12))
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
                AztecSectionHeader(title: "Squad Stats", color: AztecTheme.jade)
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
                .frame(width: 20, alignment: .center)
            Text("BALLER")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("GP")
                .frame(width: 26, alignment: .trailing)
            Text("DNG")
                .frame(width: 32, alignment: .trailing)
            Text("SAL")
                .frame(width: 28, alignment: .trailing)
            Text("DP")
                .frame(width: 24, alignment: .trailing)
            Text("DRP")
                .frame(width: 28, alignment: .trailing)
            Text("SUD")
                .frame(width: 28, alignment: .trailing)
            Text("TAC")
                .frame(width: 28, alignment: .trailing)
        }
        .font(AztecTheme.impact(size: 9))
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
            Text("\(rank)")
                .font(.system(size: 12, weight: rank <= 3 ? .black : .bold, design: .monospaced))
                .foregroundColor(
                    rank == 1 ? AztecTheme.gold :
                    rank == 2 ? AztecTheme.lightText :
                    rank == 3 ? AztecTheme.amber :
                    AztecTheme.dimText
                )
                .frame(width: 20, alignment: .center)

            Text(player.name)
                .font(AztecTheme.typewriter(size: 12))
                .foregroundColor(AztecTheme.lightText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            Text("\(player.stats.gamesPlayed)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(AztecTheme.dimText)
                .frame(width: 26, alignment: .trailing)

            Text("\(player.stats.dongs)")
                .font(.system(size: 11, weight: highlightStat == .dongs ? .black : .medium, design: .monospaced))
                .foregroundColor(highlightStat == .dongs ? AztecTheme.gold : AztecTheme.lightText)
                .frame(width: 32, alignment: .trailing)

            Text("\(player.stats.salamies)")
                .font(.system(size: 11, weight: highlightStat == .salamies ? .black : .medium, design: .monospaced))
                .foregroundColor(highlightStat == .salamies ? AztecTheme.jade : AztecTheme.lightText)
                .frame(width: 28, alignment: .trailing)

            Text("\(player.stats.doublePlays)")
                .font(.system(size: 11, weight: highlightStat == .doublePlays ? .black : .medium, design: .monospaced))
                .foregroundColor(highlightStat == .doublePlays ? AztecTheme.amber : AztecTheme.lightText)
                .frame(width: 24, alignment: .trailing)

            Text("\(player.stats.drops)")
                .font(.system(size: 11, weight: highlightStat == .drops ? .black : .medium, design: .monospaced))
                .foregroundColor(highlightStat == .drops ? AztecTheme.bloodRed : AztecTheme.lightText)
                .frame(width: 28, alignment: .trailing)

            Text("\(player.stats.suds)")
                .font(.system(size: 11, weight: highlightStat == .suds ? .black : .medium, design: .monospaced))
                .foregroundColor(highlightStat == .suds ? AztecTheme.cosmic : AztecTheme.lightText)
                .frame(width: 28, alignment: .trailing)

            Text("\(player.stats.tacos)")
                .font(.system(size: 11, weight: highlightStat == .tacos ? .black : .medium, design: .monospaced))
                .foregroundColor(highlightStat == .tacos ? AztecTheme.tennisGreen : AztecTheme.lightText)
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

struct TeamAggregatedRow: View {
    @EnvironmentObject var cloudService: CloudSyncService
    let team: Team

    var teamPlayers: [Player] {
        cloudService.playersForTeam(team.id)
    }

    var totalDongs: Int { teamPlayers.reduce(0) { $0 + $1.stats.dongs } }
    var totalSalamies: Int { teamPlayers.reduce(0) { $0 + $1.stats.salamies } }
    var totalDoublePlays: Int { teamPlayers.reduce(0) { $0 + $1.stats.doublePlays } }
    var totalSuds: Int { teamPlayers.reduce(0) { $0 + $1.stats.suds } }
    var totalTacos: Int { teamPlayers.reduce(0) { $0 + $1.stats.tacos } }

    var body: some View {
        HStack(spacing: 12) {
            TeamIconView(team: team, size: 28)

            Text(team.name)
                .font(AztecTheme.typewriterBold(size: 14))
                .foregroundColor(AztecTheme.lightText)

            Spacer()

            HStack(spacing: 12) {
                VStack(spacing: 1) {
                    Text("\(totalDongs)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(AztecTheme.gold)
                    Text("D")
                        .font(AztecTheme.impact(size: 9))
                        .foregroundColor(AztecTheme.dimText)
                }

                VStack(spacing: 1) {
                    Text("\(totalSalamies)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(AztecTheme.jade)
                    Text("S")
                        .font(AztecTheme.impact(size: 9))
                        .foregroundColor(AztecTheme.dimText)
                }

                VStack(spacing: 1) {
                    Text("\(totalDoublePlays)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(AztecTheme.amber)
                    Text("DP")
                        .font(AztecTheme.impact(size: 9))
                        .foregroundColor(AztecTheme.dimText)
                }

                VStack(spacing: 1) {
                    Text("\(totalSuds)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(AztecTheme.cosmic)
                    Text("Su")
                        .font(AztecTheme.impact(size: 9))
                        .foregroundColor(AztecTheme.dimText)
                }

                VStack(spacing: 1) {
                    Text("\(totalTacos)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(AztecTheme.tennisGreen)
                    Text("T")
                        .font(AztecTheme.impact(size: 9))
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

/// Displays a team's custom icon from Assets if set, otherwise shows the two-letter abbreviation.
struct TeamIconView: View {
    let team: Team
    var size: CGFloat = 48

    var body: some View {
        if let iconName = team.iconName {
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.125))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.125)
                    .fill(AztecTheme.gold.opacity(0.15))
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.125)
                            .stroke(AztecTheme.gold.opacity(0.4), lineWidth: 1)
                    )

                Text(String(team.name.prefix(2)).uppercased())
                    .font(AztecTheme.impact(size: size * 0.375))
                    .foregroundColor(AztecTheme.gold)
            }
        }
    }
}
