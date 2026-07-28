import SwiftUI

struct StatsView: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @State private var sortBy: StatSort = .dongs
    @State private var teamSortBy: StatSort = .dongs

    enum StatSort: String, CaseIterable {
        case dongs = "Dongs"
        case salamies = "Salamies"
        case doublePlays = "Dbl Plays"
        case drops = "Drops"
        case gamesPlayed = "GP"

        var label: String { rawValue }

        var highlightColor: Color {
            switch self {
            case .dongs: return AztecTheme.neonYellow
            case .salamies: return AztecTheme.neonYellow
            case .doublePlays: return AztecTheme.hotPink
            case .drops: return AztecTheme.hotPink
            case .gamesPlayed: return AztecTheme.neonYellow
            }
        }
    }

    private func playerStat(_ player: Player, sort: StatSort) -> Int {
        switch sort {
        case .dongs: return player.stats.dongs
        case .salamies: return player.stats.salamies
        case .doublePlays: return player.stats.doublePlays
        case .drops: return player.stats.drops
        case .gamesPlayed: return player.stats.gamesPlayed
        }
    }

    private func teamStat(_ team: Team, sort: StatSort) -> Int {
        let players = cloudService.playersForTeam(team.id)
        switch sort {
        case .dongs: return players.reduce(0) { $0 + $1.stats.dongs }
        case .salamies: return players.reduce(0) { $0 + $1.stats.salamies }
        case .doublePlays: return players.reduce(0) { $0 + $1.stats.doublePlays }
        case .drops: return players.reduce(0) { $0 + $1.stats.drops }
        case .gamesPlayed: return players.reduce(0) { $0 + $1.stats.gamesPlayed }
        }
    }

    var sortedPlayers: [Player] {
        cloudService.players
            .filter { playerStat($0, sort: sortBy) > 0 }
            .sorted { playerStat($0, sort: sortBy) > playerStat($1, sort: sortBy) }
    }

    var sortedTeams: [Team] {
        cloudService.teams
            .filter { teamStat($0, sort: teamSortBy) > 0 }
            .sorted { teamStat($0, sort: teamSortBy) > teamStat($1, sort: teamSortBy) }
    }

    private func sortButtons(selection: Binding<StatSort>) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(StatSort.allCases.enumerated()), id: \.element) { index, sort in
                Button {
                    withAnimation { selection.wrappedValue = sort }
                } label: {
                    let altColor = index % 2 == 0 ? AztecTheme.neonYellow : AztecTheme.hotPink
                    Text(sort.label)
                        .font(AztecTheme.futuraBold(size: 13))
                        .foregroundColor(
                            selection.wrappedValue == sort ? Color.black : altColor
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            selection.wrappedValue == sort
                                ? altColor
                                : Color.black
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(altColor, lineWidth: 2.25)
                        )
                        .shadow(color: selection.wrappedValue == sort
                                ? altColor.opacity(0.4) : .clear, radius: 4)
                }
            }
        }
        .padding(.horizontal)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Leaderboard header
            HStack {
                Text("LEADERBOARD")
                    .font(AztecTheme.hobbsFont(size: 43))
                    .tracking(AztecTheme.hobbsKerning)
                    .foregroundColor(AztecTheme.neonYellow)
                    .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 4)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 16)

            // Sort options — full width buttons
            sortButtons(selection: $sortBy)

            // Stats table
            if sortedPlayers.isEmpty {
                VStack(spacing: 12) {
                    Spacer().frame(height: 20)
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(AztecTheme.hotPink)
                    Text("No stats recorded yet")
                        .font(AztecTheme.futuraBold(size: 16))
                        .foregroundColor(AztecTheme.hotPink)
                    Text("Play some games to see leaderboards.")
                        .font(AztecTheme.futuraMedium(size: 14))
                        .foregroundColor(AztecTheme.neonYellow)
                    Spacer()
                }
            } else {
                // Table header
                StatsTableHeader()
                    .padding(.horizontal)

                // Player rows — scrollable section with pink indicator
                let playerList = Array(sortedPlayers.enumerated())

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(playerList, id: \.element.id) { index, player in
                            StatsTableRow(rank: index + 1, player: player, highlightStat: sortBy)
                        }
                    }
                    .padding(.horizontal)
                }
                .overlay(alignment: .trailing) {
                    Capsule()
                        .fill(AztecTheme.hotPink.opacity(0.5))
                        .frame(width: 3)
                        .padding(.vertical, 8)
                        .padding(.trailing, 2)
                }
            }

            // Team aggregated stats
            HStack {
                Text("SQUAD STATS")
                    .font(AztecTheme.hobbsFont(size: 39))
                    .tracking(AztecTheme.hobbsKerning)
                    .foregroundColor(AztecTheme.hotPink)
                    .shadow(color: AztecTheme.hotPink.opacity(0.4), radius: 4)
                Spacer()
            }
            .padding(.horizontal)

            // Team sort options — full width buttons
            sortButtons(selection: $teamSortBy)

            // Team rows — scrollable section with pink indicator
            if sortedTeams.isEmpty {
                VStack(spacing: 8) {
                    Spacer().frame(height: 12)
                    Text("No squads with \(teamSortBy.label.lowercased()) yet")
                        .font(AztecTheme.futuraBold(size: 14))
                        .foregroundColor(AztecTheme.hotPink)
                    Spacer()
                }
                .padding(.bottom, 16)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(sortedTeams) { team in
                            TeamAggregatedRow(team: team, highlightStat: teamSortBy)
                        }
                    }
                    .padding(.horizontal)
                }
                .overlay(alignment: .trailing) {
                    Capsule()
                        .fill(AztecTheme.hotPink.opacity(0.5))
                        .frame(width: 3)
                        .padding(.vertical, 8)
                        .padding(.trailing, 2)
                }
                .padding(.bottom, 16)
            }
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
                .frame(width: 24, alignment: .trailing)
            Text("DNG")
                .frame(width: 32, alignment: .trailing)
            Text("SAL")
                .frame(width: 28, alignment: .trailing)
            Text("DP")
                .frame(width: 24, alignment: .trailing)
            Text("DRP")
                .frame(width: 28, alignment: .trailing)
        }
        .font(AztecTheme.futuraBold(size: 10))
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
                .font(AztecTheme.futuraBold(size: 14))
                .foregroundColor(AztecTheme.neonYellow)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            Text("\(player.stats.gamesPlayed)")
                .font(.system(size: 11, weight: highlightStat == .gamesPlayed ? .black : .bold))
                .foregroundColor(highlightStat == .gamesPlayed ? AztecTheme.neonYellow : AztecTheme.neonYellow.opacity(0.7))
                .shadow(color: highlightStat == .gamesPlayed ? AztecTheme.neonYellow.opacity(0.3) : .clear, radius: 2)
                .frame(width: 24, alignment: .trailing)

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
    var highlightStat: StatsView.StatSort = .dongs

    var teamPlayers: [Player] {
        cloudService.playersForTeam(team.id)
    }

    var totalDongs: Int { teamPlayers.reduce(0) { $0 + $1.stats.dongs } }
    var totalSalamies: Int { teamPlayers.reduce(0) { $0 + $1.stats.salamies } }
    var totalDoublePlays: Int { teamPlayers.reduce(0) { $0 + $1.stats.doublePlays } }
    var totalDrops: Int { teamPlayers.reduce(0) { $0 + $1.stats.drops } }

    private func statColor(_ stat: StatsView.StatSort) -> Color {
        highlightStat == stat ? AztecTheme.neonYellow : AztecTheme.neonYellow.opacity(0.7)
    }

    private func statWeight(_ stat: StatsView.StatSort) -> Font {
        AztecTheme.futuraBold(size: highlightStat == stat ? 16 : 14)
    }

    var body: some View {
        HStack(spacing: 12) {
            TeamIconView(team: team, size: 28)

            Text(team.name)
                .font(AztecTheme.hobbsFont(size: 23))
                .tracking(AztecTheme.hobbsKerning)
                .foregroundColor(AztecTheme.neonYellow)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Spacer()

            HStack(spacing: 12) {
                VStack(spacing: 1) {
                    Text("\(totalDongs)")
                        .font(statWeight(.dongs))
                        .foregroundColor(statColor(.dongs))
                        .shadow(color: highlightStat == .dongs ? AztecTheme.neonYellow.opacity(0.3) : .clear, radius: 2)
                    Text("D")
                        .font(AztecTheme.futuraBold(size: 9))
                        .foregroundColor(AztecTheme.hotPink)
                }

                VStack(spacing: 1) {
                    Text("\(totalSalamies)")
                        .font(statWeight(.salamies))
                        .foregroundColor(statColor(.salamies))
                        .shadow(color: highlightStat == .salamies ? AztecTheme.neonYellow.opacity(0.3) : .clear, radius: 2)
                    Text("S")
                        .font(AztecTheme.futuraBold(size: 9))
                        .foregroundColor(AztecTheme.hotPink)
                }

                VStack(spacing: 1) {
                    Text("\(totalDoublePlays)")
                        .font(statWeight(.doublePlays))
                        .foregroundColor(statColor(.doublePlays))
                        .shadow(color: highlightStat == .doublePlays ? AztecTheme.hotPink.opacity(0.3) : .clear, radius: 2)
                    Text("DP")
                        .font(AztecTheme.futuraBold(size: 9))
                        .foregroundColor(AztecTheme.hotPink)
                }

                VStack(spacing: 1) {
                    Text("\(totalDrops)")
                        .font(statWeight(.drops))
                        .foregroundColor(statColor(.drops))
                        .shadow(color: highlightStat == .drops ? AztecTheme.hotPink.opacity(0.3) : .clear, radius: 2)
                    Text("Dr")
                        .font(AztecTheme.futuraBold(size: 9))
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
/// Uses a static mapping for team-specific icons and glow colors.
struct TeamIconView: View {
    let team: Team
    var size: CGFloat = 48
    var glowRadius: CGFloat = 10.8

    /// Maps team name → (asset name, glow color, glow intensity multiplier)
    static let teamLogos: [String: (icon: String, glowColor: Color, intensity: CGFloat)] = [
        "Mothership Champs":    ("B_GOLD",        AztecTheme.hotPink,    1.0),
        "Tinseltown Champs":    ("TTFB_GOLD",     AztecTheme.hotPink,    1.0),
        "Rose City Champs":     ("Rose-City_GOLD", AztecTheme.hotPink,   1.0),
        "Jet City Champs":      ("Jet-City_GOLD", AztecTheme.hotPink,    1.0),
        "No Mames Wey Viejos":  ("NMW_VIEJOS",    Color.white,          1.0),
        "Mothership JV Reds":   ("BJVRED",        AztecTheme.neonYellow, 1.0),
        "Mothership JV Blacks": ("B",             AztecTheme.neonYellow, 2.0),
        "Tinseltown JV":        ("TTFBJV",        AztecTheme.neonYellow, 1.0),
        "Rose City JV":         ("RCJV",          AztecTheme.neonYellow, 1.0),
        "D$$":                  ("DSS",           AztecTheme.neonYellow, 1.0),
        "Steel City":           ("Steel-City",    AztecTheme.neonYellow, 1.0),
        "Gold Coast":           ("Gold-Coast",    AztecTheme.neonYellow, 1.0),
        "Banditos":             ("Banditos",      AztecTheme.neonYellow, 1.0),
        "No Mames Wey Jovenes": ("NMW_JOVENES",   Color.white,          1.0),
    ]

    private var logoInfo: (icon: String, glowColor: Color, intensity: CGFloat)? {
        Self.teamLogos[team.name]
    }

    private var resolvedIconName: String? {
        logoInfo?.icon ?? team.iconName
    }

    private var glowColor: Color {
        logoInfo?.glowColor ?? AztecTheme.hotPink
    }

    private var glowIntensity: CGFloat {
        logoInfo?.intensity ?? 1.0
    }

    var body: some View {
        if let iconName = resolvedIconName {
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.125))
                .shadow(color: glowColor.opacity(0.6 * glowIntensity), radius: glowRadius * glowIntensity)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.125)
                    .fill(Color.black)
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.125)
                            .stroke(AztecTheme.hotPink.opacity(0.6), lineWidth: 2.25)
                    )
                    .shadow(color: AztecTheme.hotPink.opacity(0.6), radius: glowRadius)

                Text(String(team.name.prefix(2)).uppercased())
                    .font(AztecTheme.hobbsFont(size: size * 0.5))
                    .tracking(AztecTheme.hobbsKerning)
                    .foregroundColor(AztecTheme.neonYellow)
            }
        }
    }
}
