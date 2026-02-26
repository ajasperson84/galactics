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

        var highlightColor: Color {
            switch self {
            case .dongs: return AztecTheme.neonYellow
            case .salamies: return AztecTheme.jade
            case .doublePlays: return AztecTheme.hotPink
            case .drops: return AztecTheme.bloodRed
            case .suds: return AztecTheme.cosmic
            case .tacos: return AztecTheme.tennisGreen
            }
        }
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
                AztecSectionHeader(title: "Top 10 Leaderboard", shapeIndex: 0)
                    .padding(.horizontal)

                // Sort options — parallelogram shaped
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(StatSort.allCases, id: \.self) { sort in
                            Button {
                                withAnimation { sortBy = sort }
                            } label: {
                                Text(sort.label)
                                    .font(AztecTheme.hobbsFont(size: 18))
                                    .foregroundColor(
                                        sortBy == sort ? Color.black : sort.highlightColor
                                    )
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 7)
                                    .background(
                                        sortBy == sort
                                            ? sort.highlightColor
                                            : Color.clear
                                    )
                                    .clipShape(ParallelogramShape(slant: 0.15))
                                    .overlay(
                                        ParallelogramShape(slant: 0.15)
                                            .stroke(sort.highlightColor, lineWidth: 1.5)
                                    )
                                    .shadow(color: sortBy == sort
                                            ? sort.highlightColor.opacity(0.4) : .clear, radius: 4)
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
                            .font(.system(size: 40)).italic()
                            .foregroundColor(AztecTheme.stone)
                        Text("No stats recorded yet")
                            .font(AztecTheme.typewriter(size: 14))
                            .italic()
                            .foregroundColor(AztecTheme.dimText)
                        Text("Play some games to see leaderboards.")
                            .font(AztecTheme.typewriter(size: 12))
                            .italic()
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
                AztecSectionHeader(title: "Squad Stats", color: AztecTheme.jade, shapeIndex: 1)
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
        .background(AztecTheme.darkStone)
        .clipShape(RoundedRectangle(cornerRadius: 6))
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
                .italic()
                .foregroundColor(
                    rank == 1 ? AztecTheme.neonYellow :
                    rank == 2 ? AztecTheme.lightText :
                    rank == 3 ? AztecTheme.hotPink :
                    AztecTheme.dimText
                )
                .shadow(color: rank == 1 ? AztecTheme.neonYellow.opacity(0.4) : .clear, radius: 3)
                .frame(width: 20, alignment: .center)

            Text(player.name)
                .font(AztecTheme.hobbsFont(size: 16))
                .foregroundColor(AztecTheme.lightText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            Text("\(player.stats.gamesPlayed)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .italic()
                .foregroundColor(AztecTheme.dimText)
                .frame(width: 26, alignment: .trailing)

            Text("\(player.stats.dongs)")
                .font(.system(size: 11, weight: highlightStat == .dongs ? .black : .medium, design: .monospaced))
                .italic()
                .foregroundColor(highlightStat == .dongs ? AztecTheme.neonYellow : AztecTheme.lightText)
                .shadow(color: highlightStat == .dongs ? AztecTheme.neonYellow.opacity(0.3) : .clear, radius: 2)
                .frame(width: 32, alignment: .trailing)

            Text("\(player.stats.salamies)")
                .font(.system(size: 11, weight: highlightStat == .salamies ? .black : .medium, design: .monospaced))
                .italic()
                .foregroundColor(highlightStat == .salamies ? AztecTheme.jade : AztecTheme.lightText)
                .shadow(color: highlightStat == .salamies ? AztecTheme.jade.opacity(0.3) : .clear, radius: 2)
                .frame(width: 28, alignment: .trailing)

            Text("\(player.stats.doublePlays)")
                .font(.system(size: 11, weight: highlightStat == .doublePlays ? .black : .medium, design: .monospaced))
                .italic()
                .foregroundColor(highlightStat == .doublePlays ? AztecTheme.hotPink : AztecTheme.lightText)
                .shadow(color: highlightStat == .doublePlays ? AztecTheme.hotPink.opacity(0.3) : .clear, radius: 2)
                .frame(width: 24, alignment: .trailing)

            Text("\(player.stats.drops)")
                .font(.system(size: 11, weight: highlightStat == .drops ? .black : .medium, design: .monospaced))
                .italic()
                .foregroundColor(highlightStat == .drops ? AztecTheme.bloodRed : AztecTheme.lightText)
                .shadow(color: highlightStat == .drops ? AztecTheme.bloodRed.opacity(0.3) : .clear, radius: 2)
                .frame(width: 28, alignment: .trailing)

            Text("\(player.stats.suds)")
                .font(.system(size: 11, weight: highlightStat == .suds ? .black : .medium, design: .monospaced))
                .italic()
                .foregroundColor(highlightStat == .suds ? AztecTheme.cosmic : AztecTheme.lightText)
                .shadow(color: highlightStat == .suds ? AztecTheme.cosmic.opacity(0.3) : .clear, radius: 2)
                .frame(width: 28, alignment: .trailing)

            Text("\(player.stats.tacos)")
                .font(.system(size: 11, weight: highlightStat == .tacos ? .black : .medium, design: .monospaced))
                .italic()
                .foregroundColor(highlightStat == .tacos ? AztecTheme.tennisGreen : AztecTheme.lightText)
                .shadow(color: highlightStat == .tacos ? AztecTheme.tennisGreen.opacity(0.3) : .clear, radius: 2)
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(AztecTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(AztecTheme.hotPink.opacity(0.15), lineWidth: 0.5)
        )
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
                .font(AztecTheme.hobbsFont(size: 22))
                .foregroundColor(AztecTheme.lightText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Spacer()

            HStack(spacing: 12) {
                VStack(spacing: 1) {
                    Text("\(totalDongs)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .italic()
                        .foregroundColor(AztecTheme.neonYellow)
                    Text("D")
                        .font(AztecTheme.impact(size: 9))
                        .foregroundColor(AztecTheme.dimText)
                }

                VStack(spacing: 1) {
                    Text("\(totalSalamies)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .italic()
                        .foregroundColor(AztecTheme.jade)
                    Text("S")
                        .font(AztecTheme.impact(size: 9))
                        .foregroundColor(AztecTheme.dimText)
                }

                VStack(spacing: 1) {
                    Text("\(totalDoublePlays)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .italic()
                        .foregroundColor(AztecTheme.hotPink)
                    Text("DP")
                        .font(AztecTheme.impact(size: 9))
                        .foregroundColor(AztecTheme.dimText)
                }

                VStack(spacing: 1) {
                    Text("\(totalSuds)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .italic()
                        .foregroundColor(AztecTheme.cosmic)
                    Text("Su")
                        .font(AztecTheme.impact(size: 9))
                        .foregroundColor(AztecTheme.dimText)
                }

                VStack(spacing: 1) {
                    Text("\(totalTacos)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .italic()
                        .foregroundColor(AztecTheme.tennisGreen)
                    Text("T")
                        .font(AztecTheme.impact(size: 9))
                        .foregroundColor(AztecTheme.dimText)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .neonCard(glow: 0.4)
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
                    .fill(AztecTheme.hotPink.opacity(0.12))
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.125)
                            .stroke(AztecTheme.hotPink.opacity(0.4), lineWidth: 1)
                    )

                Text(String(team.name.prefix(2)).uppercased())
                    .font(AztecTheme.hobbsFont(size: size * 0.5))
                    .foregroundColor(AztecTheme.neonYellow)
            }
        }
    }
}
