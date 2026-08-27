import SwiftUI

// MARK: - Shared Bracket Abbreviations

/// Abbreviated team names for compact bracket display. Shared between
/// `BracketView` and `BracketGameNode` to avoid duplication.
enum BracketAbbreviations {
    static let nameMap: [String: String] = [
        "Tinseltown Champs": "TTFB Champs",
        "Tinseltown JV": "TTFB JV",
        "Rose City Champs": "Rose Champs",
        "Rose City JV": "Rose JV",
        "Mothership Champs": "Mother Champs",
        "Mothership JV Blacks": "Mother Black JV",
        "Mothership JV Reds": "Mother Red JV",
        "No Mames Wey Jovenes": "Jovenes",
        "No Mames Wey Viejos": "Viejos",
        "Jet City Champs": "Jets",
        "Steel City": "Steel",
        "Banditos": "Bandits",
        "Gold Coast": "Coast",
        "D$$": "D$$",
    ]

    static func displayName(for team: Team) -> String {
        nameMap[team.name] ?? String(team.name.prefix(8))
    }
}

struct BracketView: View {
    @EnvironmentObject var cloudService: CloudSyncService
    let tier: TournamentTier
    let tierIndex: Int
    var onTapGame: ((TournamentGame) -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            // Winners Bracket
            if !tier.winnersBracketRounds.isEmpty {
                bracketSection(
                    title: "WINNERS BRACKET",
                    color: AztecTheme.neonYellow,
                    rounds: tier.winnersBracketRounds,
                    advancingLabel: winnersAdvancingLabel
                )
            }

            // Losers Bracket
            if !tier.losersBracketRounds.isEmpty {
                bracketSection(
                    title: "LOSERS BRACKET",
                    color: AztecTheme.hotPink,
                    rounds: tier.losersBracketRounds,
                    advancingLabel: losersAdvancingLabel
                )
            }

            // Championship
            if let champId = tier.championshipGameId, let champGame = tier.game(byId: champId) {
                VStack(spacing: 8) {
                    HStack {
                        Text("CHAMPIONSHIP")
                            .font(AztecTheme.hobbsFont(size: 35))
                            .tracking(AztecTheme.hobbsKerning)
                            .foregroundColor(AztecTheme.neonYellow)
                            .shadow(color: AztecTheme.neonYellow.opacity(0.5), radius: 4)
                        Rectangle()
                            .fill(AztecTheme.neonYellow.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal)

                    GameCard(game: champGame, tier: tier) {
                        onTapGame?(champGame)
                    }
                    .padding(.horizontal)
                }
            }

            // If Necessary
            if let ifNecId = tier.ifNecessaryGameId, let ifNecGame = tier.game(byId: ifNecId) {
                let isActivated = ifNecGame.team1Id != nil && ifNecGame.team2Id != nil
                if isActivated {
                    VStack(spacing: 8) {
                        HStack {
                            Text("IF NECESSARY")
                                .font(AztecTheme.hobbsFont(size: 35))
                                .tracking(AztecTheme.hobbsKerning)
                                .foregroundColor(AztecTheme.hotPink)
                                .shadow(color: AztecTheme.hotPink.opacity(0.5), radius: 4)
                            Rectangle()
                                .fill(AztecTheme.hotPink.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.horizontal)

                        GameCard(game: ifNecGame, tier: tier) {
                            onTapGame?(ifNecGame)
                        }
                        .padding(.horizontal)
                    }
                }
            }

        }
    }

    private var winnersAdvancingLabel: String? {
        switch tierIndex {
        case 0: return "ADVANCING\nTEAMS"
        case 1: return "ADVANCING\nTEAMS"
        case 2: return "GALACTICOS 4\nCHAMPS"
        default: return nil
        }
    }

    private var losersAdvancingLabel: String? {
        switch tierIndex {
        case 0: return "ADVANCING\nTEAM"
        case 1: return "ADVANCING\nTEAMS"
        default: return nil
        }
    }

    private var tournamentChampion: Team? {
        if let ifNecId = tier.ifNecessaryGameId,
           let ifNecGame = tier.game(byId: ifNecId),
           ifNecGame.status == .completed,
           let winnerId = ifNecGame.winnerId {
            return cloudService.team(for: winnerId)
        }
        if let champId = tier.championshipGameId,
           let champGame = tier.game(byId: champId),
           champGame.status == .completed,
           let winnerId = champGame.winnerId {
            return cloudService.team(for: winnerId)
        }
        return nil
    }

    private let nodeHeight: CGFloat = 56
    private let nodeGap: CGFloat = 12

    private func computePositions(rounds: [BracketRoundGroup]) -> (positions: [String: CGFloat], totalHeight: CGFloat) {
        var positions: [String: CGFloat] = [:]
        guard !rounds.isEmpty else { return (positions, 0) }

        let maxCount = rounds.map { $0.gameIds.count }.max() ?? 1
        let cellHeight = nodeHeight + nodeGap
        let totalHeight = CGFloat(maxCount) * cellHeight

        // Find densest round index
        let maxRoundIdx = rounds.firstIndex { $0.gameIds.count == maxCount } ?? 0

        // Position densest round evenly
        for (i, gameId) in rounds[maxRoundIdx].gameIds.enumerated() {
            positions[gameId] = CGFloat(i) * cellHeight + cellHeight / 2
        }

        // Forward: densest → last
        for roundIdx in (maxRoundIdx + 1)..<rounds.count {
            let prevRound = rounds[roundIdx - 1]
            for gameId in rounds[roundIdx].gameIds {
                var sourceYs: [CGFloat] = []
                for srcId in prevRound.gameIds {
                    if let g = tier.game(byId: srcId),
                       let link = g.feedsWinnerTo,
                       link.gameId == gameId,
                       let y = positions[srcId] {
                        sourceYs.append(y)
                    }
                }
                if !sourceYs.isEmpty {
                    positions[gameId] = sourceYs.reduce(0, +) / CGFloat(sourceYs.count)
                } else {
                    let idx = rounds[roundIdx].gameIds.firstIndex(of: gameId) ?? 0
                    positions[gameId] = CGFloat(idx) * cellHeight + cellHeight / 2
                }
            }
        }

        // Backward: densest → first
        for roundIdx in stride(from: maxRoundIdx - 1, through: 0, by: -1) {
            let nextRound = rounds[roundIdx + 1]
            for gameId in rounds[roundIdx].gameIds {
                if let game = tier.game(byId: gameId),
                   let link = game.feedsWinnerTo,
                   nextRound.gameIds.contains(link.gameId),
                   let targetY = positions[link.gameId] {
                    positions[gameId] = targetY
                } else {
                    let idx = rounds[roundIdx].gameIds.firstIndex(of: gameId) ?? 0
                    positions[gameId] = CGFloat(idx) * cellHeight + cellHeight / 2
                }
            }
        }

        return (positions, totalHeight)
    }

    private func bracketDisplayName(for team: Team) -> String {
        BracketAbbreviations.displayName(for: team)
    }

    private func bracketSection(title: String, color: Color, rounds: [BracketRoundGroup], advancingLabel: String? = nil) -> some View {
        let (positions, totalHeight) = computePositions(rounds: rounds)
        let isChampColumn = advancingLabel?.contains("GALACTICOS") == true
        let iconSize: CGFloat = isChampColumn ? 32 : 26
        let fontSize: CGFloat = isChampColumn ? 14 : 12
        let labelFontSize: CGFloat = isChampColumn ? 12 : 10
        let columnWidth: CGFloat = isChampColumn ? 180 : 160

        return VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(AztecTheme.hobbsFont(size: 35))
                    .tracking(AztecTheme.hobbsKerning)
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.5), radius: 4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Rectangle()
                    .fill(color.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(rounds.enumerated()), id: \.offset) { roundIdx, roundGroup in
                        VStack(spacing: 0) {
                            ZStack {
                                ForEach(roundGroup.gameIds, id: \.self) { gameId in
                                    if let game = tier.game(byId: gameId),
                                       let yCenter = positions[gameId],
                                       !(game.status == .completed && game.team2Id == nil) {
                                        BracketGameNode(game: game, tier: tier, accentColor: color) {
                                            onTapGame?(game)
                                        }
                                        .frame(height: nodeHeight)
                                        .position(x: 80, y: yCenter)
                                    }
                                }
                            }
                            .frame(width: 160, height: totalHeight)
                        }

                        if roundIdx < rounds.count - 1 {
                            VStack(spacing: 0) {
                                RoutedConnectors(
                                    tier: tier,
                                    fromGameIds: roundGroup.gameIds,
                                    toGameIds: rounds[roundIdx + 1].gameIds,
                                    positions: positions,
                                    color: color
                                )
                                .frame(width: 24, height: totalHeight)
                            }
                        }
                    }

                    // Advancing teams column after last round
                    if let label = advancingLabel, let lastRound = rounds.last {
                        // Connector lines from last round to winners
                        ZStack {
                            Path { path in
                                if isChampColumn {
                                    if let champTeam = tournamentChampion {
                                        let midY = totalHeight / 2
                                        _ = champTeam
                                        path.move(to: CGPoint(x: 0, y: midY))
                                        path.addLine(to: CGPoint(x: 24, y: midY))
                                    }
                                } else {
                                    for gameId in lastRound.gameIds {
                                        guard let game = tier.game(byId: gameId),
                                              game.status == .completed,
                                              game.winnerId != nil,
                                              let yCenter = positions[gameId] else { continue }
                                        path.move(to: CGPoint(x: 0, y: yCenter))
                                        path.addLine(to: CGPoint(x: 24, y: yCenter))
                                    }
                                }
                            }
                            .stroke(color.opacity(0.3), lineWidth: 1)
                        }
                        .frame(width: 24, height: totalHeight)

                        // Advancing teams display
                        ZStack {
                            Text(label)
                                .font(AztecTheme.sfProBold(size: labelFontSize))
                                .tracking(1)
                                .foregroundColor(color)
                                .multilineTextAlignment(.center)
                                .position(x: columnWidth / 2, y: 14)

                            if isChampColumn {
                                if let team = tournamentChampion {
                                    HStack(spacing: 6) {
                                        TeamIconView(team: team, size: iconSize, glowRadius: 4)
                                        Text(team.name.uppercased())
                                            .font(AztecTheme.sfProBold(size: fontSize))
                                            .foregroundColor(AztecTheme.neonYellow)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.5)
                                    }
                                    .position(x: columnWidth / 2, y: totalHeight / 2)
                                }
                            } else {
                                ForEach(lastRound.gameIds, id: \.self) { gameId in
                                    if let game = tier.game(byId: gameId),
                                       game.status == .completed,
                                       let winnerId = game.winnerId,
                                       let team = cloudService.team(for: winnerId),
                                       let yCenter = positions[gameId] {
                                        HStack(spacing: 6) {
                                            TeamIconView(team: team, size: iconSize, glowRadius: 4)
                                            Text(team.name.uppercased())
                                                .font(AztecTheme.sfProBold(size: fontSize))
                                                .foregroundColor(AztecTheme.neonYellow)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.5)
                                        }
                                        .position(x: columnWidth / 2, y: yCenter)
                                    }
                                }
                            }
                        }
                        .frame(width: columnWidth, height: totalHeight)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Bracket Game Node (compact card for bracket view)

struct BracketGameNode: View {
    @EnvironmentObject var cloudService: CloudSyncService
    let game: TournamentGame
    var tier: TournamentTier?
    var accentColor: Color = AztecTheme.neonYellow
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: 2) {
                // Game number + inning
                HStack(spacing: 4) {
                    Text("G\(game.gameNumber)")
                        .font(AztecTheme.sfProBold(size: 9))
                        .foregroundColor(accentColor.opacity(0.7))
                    if game.status == .inProgress, let inning = game.currentInning {
                        Text("INN \(inning)")
                            .font(AztecTheme.sfProBold(size: 8))
                            .foregroundColor(AztecTheme.neonYellow)
                            .shadow(color: AztecTheme.neonYellow.opacity(0.5), radius: 2)
                    }
                }

                // Team 1 row
                teamRow(
                    teamId: game.team1Id,
                    slot: .team1,
                    score: game.team1Score,
                    isWinner: game.winnerId == game.team1Id && game.status == .completed
                )

                Rectangle()
                    .fill(accentColor.opacity(0.2))
                    .frame(height: 0.5)

                // Team 2 row
                teamRow(
                    teamId: game.team2Id,
                    slot: .team2,
                    score: game.team2Score,
                    isWinner: game.winnerId == game.team2Id && game.status == .completed
                )
            }
            .padding(6)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        AztecTheme.borderGradient,
                        lineWidth: game.status == .inProgress ? 1.7 : 1.28
                    )
            )
            .shadow(color: AztecTheme.neonYellow.opacity(0.2), radius: 3, x: -1)
            .shadow(color: AztecTheme.hotPink.opacity(0.2), radius: 3, x: 1)
            .shadow(color: game.status == .inProgress ? accentColor.opacity(0.3) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
    }

    private func bracketDisplayName(for team: Team) -> String {
        BracketAbbreviations.displayName(for: team)
    }

    private func teamRow(teamId: String?, slot: TeamSlot, score: Int, isWinner: Bool) -> some View {
        HStack(spacing: 4) {
            if let teamId, let team = cloudService.team(for: teamId) {
                Text(bracketDisplayName(for: team).uppercased())
                    .font(AztecTheme.sfProBold(size: 10))
                    .foregroundColor(isWinner ? AztecTheme.neonYellow : AztecTheme.lightText)
                    .shadow(color: isWinner ? AztecTheme.neonYellow.opacity(0.7) : .clear, radius: isWinner ? 4 : 0)
                    .lineLimit(1)
            } else {
                let desc = tier?.slotDescription(gameId: game.id, slot: slot) ?? "TBD"
                Text(desc.uppercased())
                    .font(AztecTheme.sfProBold(size: 9))
                    .foregroundColor(AztecTheme.dimText)
                    .lineLimit(1)
            }

            Spacer()

            if game.status == .completed || game.status == .inProgress {
                Text("\(score)")
                    .font(.system(size: 11, weight: isWinner ? .black : .bold, design: .monospaced))
                    .foregroundColor(isWinner ? AztecTheme.neonYellow : AztecTheme.dimText)
                    .shadow(color: isWinner ? AztecTheme.neonYellow.opacity(0.8) : .clear, radius: isWinner ? 6 : 0)
            }
        }
    }
}

// MARK: - Routed Connectors (draws lines based on feedsWinnerTo links)

struct RoutedConnectors: View {
    let tier: TournamentTier
    let fromGameIds: [String]
    let toGameIds: [String]
    var positions: [String: CGFloat] = [:]
    var color: Color = AztecTheme.hotPink

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width

                for fromId in fromGameIds {
                    guard let game = tier.game(byId: fromId),
                          let link = game.feedsWinnerTo,
                          toGameIds.contains(link.gameId),
                          let fromY = positions[fromId],
                          let toY = positions[link.gameId] else { continue }

                    path.move(to: CGPoint(x: 0, y: fromY))
                    path.addLine(to: CGPoint(x: w / 2, y: fromY))
                    path.addLine(to: CGPoint(x: w / 2, y: toY))
                    path.addLine(to: CGPoint(x: w, y: toY))
                }
            }
            .stroke(color.opacity(0.3), lineWidth: 1)
        }
    }
}
