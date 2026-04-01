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
            case .salamies: return AztecTheme.neonYellow
            case .doublePlays: return AztecTheme.hotPink
            case .drops: return AztecTheme.hotPink
            case .suds: return AztecTheme.neonYellow
            case .tacos: return AztecTheme.neonYellow
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
                // Leaderboard header — 50% larger, just "Leaderboard"
                HStack {
                    Text("LEADERBOARD")
                        .font(AztecTheme.hobbsFont(size: 36))
                        .tracking(AztecTheme.hobbsKerning)
                        .foregroundColor(AztecTheme.neonYellow)
                        .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 4)
                    Spacer()
                }
                .padding(.horizontal)

                // Sort options — SF Pro, alternating yellow/pink
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(StatSort.allCases.enumerated()), id: \.element) { index, sort in
                            Button {
                                withAnimation { sortBy = sort }
                            } label: {
                                let altColor = index % 2 == 0 ? AztecTheme.neonYellow : AztecTheme.hotPink
                                Text(sort.label)
                                    .font(AztecTheme.sfProBold(size: 16))
                                    .foregroundColor(
                                        sortBy == sort ? Color.black : altColor
                                    )
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 7)
                                    .background(
                                        sortBy == sort
                                            ? altColor
                                            : Color.black
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(altColor, lineWidth: 2.25)
                                    )
                                    .shadow(color: sortBy == sort
                                            ? altColor.opacity(0.4) : .clear, radius: 4)
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
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(AztecTheme.hotPink)
                        Text("No stats recorded yet")
                            .font(AztecTheme.sfProBold(size: 16))
                            .foregroundColor(AztecTheme.hotPink)
                        Text("Play some games to see leaderboards.")
                            .font(AztecTheme.sfProMedium(size: 14))
                            .foregroundColor(AztecTheme.neonYellow)
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
                HStack {
                    Text("SQUAD STATS")
                        .font(AztecTheme.hobbsFont(size: 26))
                        .tracking(AztecTheme.hobbsKerning)
                        .foregroundColor(AztecTheme.hotPink)
                        .shadow(color: AztecTheme.hotPink.opacity(0.4), radius: 4)
                    Spacer()
                }
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
        .font(AztecTheme.sfProBold(size: 10))
        .foregroundColor(AztecTheme.hotPink)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(AztecTheme.hotPink.opacity(0.3), lineWidth: 2.25)
        )
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
                    rank == 1 ? AztecTheme.neonYellow :
                    rank == 2 ? AztecTheme.lightText :
                    rank == 3 ? AztecTheme.hotPink :
                    AztecTheme.dimText
                )
                .shadow(color: rank == 1 ? AztecTheme.neonYellow.opacity(0.4) : .clear, radius: 3)
                .frame(width: 20, alignment: .center)

            Text(player.name)
                .font(AztecTheme.hobbsFont(size: 20))
                .tracking(AztecTheme.hobbsKerning)
                .foregroundColor(AztecTheme.neonYellow)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            Text("\(player.stats.dongs)")
                .font(.system(size: 11, weight: highlightStat == .dongs ? .black : .bold))
                .foregroundColor(highlightStat == .dongs ? AztecTheme.neonYellow : AztecTheme.neonYellow.opacity(0.7))
                .shadow(color: highlightStat == .dongs ? AztecTheme.neonYellow.opacity(0.3) : .clear, radius: 2)
                .frame(width: 32, alignment: .trailing)

            Text("\(player.stats.salamies)")
                .font(.system(size: 11, weight: highlightStat == .salamies ? .black : .bold))
                .foregroundColor(highlightStat == .salamies ? AztecTheme.neonYellow : AztecTheme.neonYellow.opacity(0.7))
                .shadow(color: highlightStat == .salamies ? AztecTheme.neonYellow.opacity(0.3) : .clear, radius: 2)
                .frame(width: 28, alignment: .trailing)

            Text("\(player.stats.doublePlays)")
                .font(.system(size: 11, weight: highlightStat == .doublePlays ? .black : .bold))
                .foregroundColor(highlightStat == .doublePlays ? AztecTheme.hotPink : AztecTheme.hotPink.opacity(0.7))
                .shadow(color: highlightStat == .doublePlays ? AztecTheme.hotPink.opacity(0.3) : .clear, radius: 2)
                .frame(width: 24, alignment: .trailing)

            Text("\(player.stats.drops)")
                .font(.system(size: 11, weight: highlightStat == .drops ? .black : .bold))
                .foregroundColor(highlightStat == .drops ? AztecTheme.hotPink : AztecTheme.hotPink.opacity(0.7))
                .shadow(color: highlightStat == .drops ? AztecTheme.hotPink.opacity(0.3) : .clear, radius: 2)
                .frame(width: 28, alignment: .trailing)

            Text("\(player.stats.suds)")
                .font(.system(size: 11, weight: highlightStat == .suds ? .black : .bold))
                .foregroundColor(highlightStat == .suds ? AztecTheme.neonYellow : AztecTheme.neonYellow.opacity(0.7))
                .shadow(color: highlightStat == .suds ? AztecTheme.neonYellow.opacity(0.3) : .clear, radius: 2)
                .frame(width: 28, alignment: .trailing)

            Text("\(player.stats.tacos)")
                .font(.system(size: 11, weight: highlightStat == .tacos ? .black : .bold))
                .foregroundColor(highlightStat == .tacos ? AztecTheme.neonYellow : AztecTheme.neonYellow.opacity(0.7))
                .shadow(color: highlightStat == .tacos ? AztecTheme.neonYellow.opacity(0.3) : .clear, radius: 2)
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(AztecTheme.hotPink.opacity(0.3), lineWidth: 1.5)
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
                .font(AztecTheme.sfProBold(size: 20))
                .foregroundColor(AztecTheme.neonYellow)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Spacer()

            HStack(spacing: 12) {
                VStack(spacing: 1) {
                    Text("\(totalDongs)")
                        .font(AztecTheme.sfProBold(size: 14))
                        .foregroundColor(AztecTheme.neonYellow)
                    Text("D")
                        .font(AztecTheme.sfProBold(size: 9))
                        .foregroundColor(AztecTheme.hotPink)
                }

                VStack(spacing: 1) {
                    Text("\(totalSalamies)")
                        .font(AztecTheme.sfProBold(size: 14))
                        .foregroundColor(AztecTheme.neonYellow)
                    Text("S")
                        .font(AztecTheme.sfProBold(size: 9))
                        .foregroundColor(AztecTheme.hotPink)
                }

                VStack(spacing: 1) {
                    Text("\(totalDoublePlays)")
                        .font(AztecTheme.sfProBold(size: 14))
                        .foregroundColor(AztecTheme.neonYellow)
                    Text("DP")
                        .font(AztecTheme.sfProBold(size: 9))
                        .foregroundColor(AztecTheme.hotPink)
                }

                VStack(spacing: 1) {
                    Text("\(totalSuds)")
                        .font(AztecTheme.sfProBold(size: 14))
                        .foregroundColor(AztecTheme.neonYellow)
                    Text("Su")
                        .font(AztecTheme.sfProBold(size: 9))
                        .foregroundColor(AztecTheme.hotPink)
                }

                VStack(spacing: 1) {
                    Text("\(totalTacos)")
                        .font(AztecTheme.sfProBold(size: 14))
                        .foregroundColor(AztecTheme.neonYellow)
                    Text("T")
                        .font(AztecTheme.sfProBold(size: 9))
                        .foregroundColor(AztecTheme.hotPink)
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
                .shadow(color: AztecTheme.hotPink.opacity(0.6), radius: 6)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.125)
                    .fill(Color.black)
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.125)
                            .stroke(AztecTheme.hotPink.opacity(0.6), lineWidth: 2.25)
                    )

                Text(String(team.name.prefix(2)).uppercased())
                    .font(AztecTheme.hobbsFont(size: size * 0.5))
                    .tracking(AztecTheme.hobbsKerning)
                    .foregroundColor(AztecTheme.neonYellow)
            }
        }
    }
}
