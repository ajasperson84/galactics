import SwiftUI

struct BracketView: View {
    let tier: TournamentTier
    let tierIndex: Int
    var onTapGame: ((TournamentGame) -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            // Tier header
            HStack {
                Text(tier.tierName.uppercased())
                    .font(AztecTheme.hobbsFont(size: 40))
                    .tracking(AztecTheme.hobbsKerning)
                    .foregroundColor(AztecTheme.neonYellow)
                    .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 4)
                Spacer()
            }
            .padding(.horizontal)

            // Winners Bracket
            if !tier.winnersBracketGameIds.isEmpty {
                bracketSection(
                    title: "WINNERS BRACKET",
                    color: AztecTheme.neonYellow,
                    rounds: tier.winnersBracketGameIds
                )
            }

            // Losers Bracket
            if !tier.losersBracketGameIds.isEmpty {
                bracketSection(
                    title: "LOSERS BRACKET",
                    color: AztecTheme.hotPink,
                    rounds: tier.losersBracketGameIds
                )
            }

            // Championship
            if let champId = tier.championshipGameId, let champGame = tier.game(byId: champId) {
                VStack(spacing: 8) {
                    HStack {
                        Text("CHAMPIONSHIP")
                            .font(AztecTheme.sfProBold(size: 14))
                            .tracking(2)
                            .foregroundColor(AztecTheme.neonYellow)
                            .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 3)
                        Rectangle()
                            .fill(AztecTheme.neonYellow.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal)

                    GameCard(game: champGame) {
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
                                .font(AztecTheme.sfProBold(size: 14))
                                .tracking(2)
                                .foregroundColor(AztecTheme.hotPink)
                                .shadow(color: AztecTheme.hotPink.opacity(0.4), radius: 3)
                            Rectangle()
                                .fill(AztecTheme.hotPink.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.horizontal)

                        GameCard(game: ifNecGame) {
                            onTapGame?(ifNecGame)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    private func bracketSection(title: String, color: Color, rounds: [[String]]) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(AztecTheme.sfProBold(size: 14))
                    .tracking(2)
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.3), radius: 3)
                Rectangle()
                    .fill(color.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal)

            // Horizontally scrollable bracket rounds
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(Array(rounds.enumerated()), id: \.offset) { roundIdx, gameIds in
                        VStack(spacing: 4) {
                            // Round header
                            Text("RD \(roundIdx + 1)")
                                .font(AztecTheme.sfProBold(size: 10))
                                .foregroundColor(color.opacity(0.7))
                                .padding(.bottom, 4)

                            // Games in this round
                            ForEach(gameIds, id: \.self) { gameId in
                                if let game = tier.game(byId: gameId) {
                                    // Skip bye games in bracket view
                                    if !(game.status == .completed && game.team2Id == nil) {
                                        BracketGameNode(game: game, accentColor: color) {
                                            onTapGame?(game)
                                        }
                                    }
                                }
                            }

                            Spacer()
                        }
                        .frame(width: 160)

                        // Connector column between rounds (except after last)
                        if roundIdx < rounds.count - 1 {
                            BracketConnectors(
                                fromCount: gameIds.count,
                                toCount: roundIdx + 1 < rounds.count ? rounds[roundIdx + 1].count : 1,
                                color: color
                            )
                            .frame(width: 24)
                        }
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
    var accentColor: Color = AztecTheme.neonYellow
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: 2) {
                // Game number
                Text("G\(game.gameNumber)")
                    .font(AztecTheme.sfProBold(size: 9))
                    .foregroundColor(accentColor.opacity(0.7))

                // Team 1 row
                teamRow(
                    teamId: game.team1Id,
                    score: game.team1Score,
                    isWinner: game.winnerId == game.team1Id && game.status == .completed
                )

                Rectangle()
                    .fill(accentColor.opacity(0.2))
                    .frame(height: 0.5)

                // Team 2 row
                teamRow(
                    teamId: game.team2Id,
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
                        game.status == .inProgress ? accentColor : accentColor.opacity(0.4),
                        lineWidth: game.status == .inProgress ? 2 : 1.5
                    )
            )
            .shadow(color: game.status == .inProgress ? accentColor.opacity(0.3) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
    }

    private func teamRow(teamId: String?, score: Int, isWinner: Bool) -> some View {
        HStack(spacing: 4) {
            if let teamId, let team = cloudService.team(for: teamId) {
                Text(String(team.name.prefix(6)).uppercased())
                    .font(AztecTheme.sfProBold(size: 10))
                    .foregroundColor(isWinner ? AztecTheme.neonYellow : AztecTheme.lightText)
                    .lineLimit(1)
            } else {
                Text("TBD")
                    .font(AztecTheme.sfProBold(size: 10))
                    .foregroundColor(AztecTheme.dimText)
            }

            Spacer()

            if game.status == .completed || game.status == .inProgress {
                Text("\(score)")
                    .font(.system(size: 11, weight: isWinner ? .black : .bold, design: .monospaced))
                    .foregroundColor(isWinner ? AztecTheme.neonYellow : AztecTheme.dimText)
            }
        }
    }
}

// MARK: - Bracket Connectors

struct BracketConnectors: View {
    let fromCount: Int
    let toCount: Int
    var color: Color = AztecTheme.hotPink

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let h = geo.size.height
                let w = geo.size.width

                let fromSpacing = fromCount > 0 ? h / CGFloat(fromCount) : h
                let toSpacing = toCount > 0 ? h / CGFloat(toCount) : h

                for i in 0..<toCount {
                    let toY = toSpacing * CGFloat(i) + toSpacing / 2
                    let from1 = i * 2
                    let from2 = i * 2 + 1

                    if from1 < fromCount {
                        let fromY1 = fromSpacing * CGFloat(from1) + fromSpacing / 2
                        path.move(to: CGPoint(x: 0, y: fromY1))
                        path.addLine(to: CGPoint(x: w / 2, y: fromY1))
                        path.addLine(to: CGPoint(x: w / 2, y: toY))
                        path.addLine(to: CGPoint(x: w, y: toY))
                    }

                    if from2 < fromCount {
                        let fromY2 = fromSpacing * CGFloat(from2) + fromSpacing / 2
                        path.move(to: CGPoint(x: 0, y: fromY2))
                        path.addLine(to: CGPoint(x: w / 2, y: fromY2))
                        path.addLine(to: CGPoint(x: w / 2, y: toY))
                        path.addLine(to: CGPoint(x: w, y: toY))
                    }
                }
            }
            .stroke(color.opacity(0.3), lineWidth: 1)
        }
    }
}
