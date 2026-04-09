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
            // Tier header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.tierName.uppercased())
                        .font(AztecTheme.hobbsFont(size: 40))
                        .tracking(AztecTheme.hobbsKerning)
                        .foregroundColor(AztecTheme.neonYellow)
                        .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 4)

                    Text(tier.dayLabel.uppercased())
                        .font(AztecTheme.sfProBold(size: 14))
                        .foregroundColor(AztecTheme.hotPink)
                }
                Spacer()

                // Tier status badge
                Text(tier.status.rawValue.uppercased())
                    .font(AztecTheme.sfProBold(size: 11))
                    .foregroundColor(tier.status == .inProgress ? AztecTheme.neonYellow : AztecTheme.dimText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                tier.status == .inProgress ? AztecTheme.neonYellow : AztecTheme.hotPink.opacity(0.3),
                                lineWidth: 1.5
                            )
                    )
            }
            .padding(.horizontal)

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
                // Group games by bracket section
                let wbGames = playableGames.filter { $0.bracketSide == .winners }
                let lbGames = playableGames.filter { $0.bracketSide == .losers }
                let champGames = playableGames.filter { $0.bracketSide == .championship || $0.bracketSide == .ifNecessary }

                if !wbGames.isEmpty {
                    sectionHeader("WINNERS BRACKET", color: AztecTheme.neonYellow)
                    ForEach(wbGames) { game in
                        GameCard(game: game) {
                            onTapGame?(game)
                        }
                    }
                    .padding(.horizontal)
                }

                if !lbGames.isEmpty {
                    sectionHeader("LOSERS BRACKET", color: AztecTheme.hotPink)
                    ForEach(lbGames) { game in
                        GameCard(game: game) {
                            onTapGame?(game)
                        }
                    }
                    .padding(.horizontal)
                }

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
                .font(AztecTheme.sfProBold(size: 14))
                .tracking(2)
                .foregroundColor(color)
                .shadow(color: color.opacity(0.3), radius: 3)
            Rectangle()
                .fill(color.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
