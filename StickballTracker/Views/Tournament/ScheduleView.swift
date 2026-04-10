import SwiftUI

struct ScheduleView: View {
    let tier: TournamentTier
    let tierIndex: Int
    var onTapGame: ((TournamentGame) -> Void)?

    private var playableGames: [TournamentGame] {
        // Filter out bye games (completed with no team2) and show real games
        tier.sortedGames.filter { game in
            // Hide if-necessary game unless it's been activated (has both teams)
            if game.bracketSide == .ifNecessary && (game.team1Id == nil || game.team2Id == nil) {
                return false
            }
            // Hide bye games
            if game.status == .completed && game.team2Id == nil {
                return false
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            if playableGames.isEmpty {
                VStack(spacing: 12) {
                    Spacer().frame(height: 20)
                    Image(systemName: "calendar")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AztecTheme.hotPink)
                    Text("No games scheduled yet")
                        .font(AztecTheme.sfProBold(size: 16))
                        .foregroundColor(AztecTheme.hotPink)
                }
            } else {
                // Winners Bracket — grouped by round
                if !tier.winnersBracketRounds.isEmpty {
                    sectionHeader("WINNERS BRACKET", color: AztecTheme.neonYellow)
                    ForEach(tier.winnersBracketRounds) { roundGroup in
                        roundSubHeader(roundGroup.name, color: AztecTheme.neonYellow)
                        ForEach(gamesForRound(roundGroup)) { game in
                            GameCard(game: game, tier: tier) {
                                onTapGame?(game)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Losers Bracket — grouped by round
                if !tier.losersBracketRounds.isEmpty {
                    sectionHeader("LOSERS BRACKET", color: AztecTheme.hotPink)
                    ForEach(tier.losersBracketRounds) { roundGroup in
                        roundSubHeader(roundGroup.name, color: AztecTheme.hotPink)
                        ForEach(gamesForRound(roundGroup)) { game in
                            GameCard(game: game, tier: tier) {
                                onTapGame?(game)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Championship
                let champGames = playableGames.filter { $0.bracketSide == .championship || $0.bracketSide == .ifNecessary }
                if !champGames.isEmpty {
                    sectionHeader("CHAMPIONSHIP", color: AztecTheme.neonYellow)
                    ForEach(champGames) { game in
                        GameCard(game: game) {
                            onTapGame?(game)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(AztecTheme.hobbsFont(size: 38))
                .tracking(AztecTheme.hobbsKerning)
                .foregroundColor(color)
                .shadow(color: color.opacity(0.5), radius: 4)
            Rectangle()
                .fill(color.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func roundSubHeader(_ title: String, color: Color) -> some View {
        HStack {
            Text(title.uppercased())
                .font(AztecTheme.hobbsFont(size: 28))
                .tracking(AztecTheme.hobbsKerning)
                .foregroundColor(color)
                .shadow(color: color.opacity(0.5), radius: 4)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private func gamesForRound(_ roundGroup: BracketRoundGroup) -> [TournamentGame] {
        roundGroup.gameIds.compactMap { id in
            tier.game(byId: id)
        }.filter { game in
            // Apply same filtering as playableGames
            if game.bracketSide == .ifNecessary && (game.team1Id == nil || game.team2Id == nil) {
                return false
            }
            if game.status == .completed && game.team2Id == nil {
                return false
            }
            return true
        }
    }
}
