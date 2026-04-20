import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var cloudService: CloudSyncService
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
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Rectangle()
                .fill(color.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal)
        .padding(.top, 8)
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

// MARK: - PIN Entry Sheet

struct PinEntrySheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    @State private var enteredPIN = ""
    @State private var shakeOffset: CGFloat = 0
    @State private var showError = false

    private let scorekeeperCode = "5687"
    private let adminCode = "3255"
    private let pinLength = 4

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    Image(systemName: cloudService.accessLevel == .viewOnly ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(cloudService.accessLevel == .viewOnly ? AztecTheme.hotPink : AztecTheme.neonYellow)
                        .shadow(color: (cloudService.accessLevel == .viewOnly ? AztecTheme.hotPink : AztecTheme.neonYellow).opacity(0.5), radius: 8)

                    Text(cloudService.accessLevel == .viewOnly ? "ENTER PIN" : "UNLOCKED")
                        .font(AztecTheme.hobbsFont(size: 36))
                        .tracking(AztecTheme.hobbsKerning)
                        .foregroundColor(AztecTheme.neonYellow)

                    if cloudService.accessLevel != .viewOnly {
                        Text(cloudService.accessLevel == .admin ? "ADMIN ACCESS" : "SCOREKEEPER ACCESS")
                            .font(AztecTheme.sfProBold(size: 16))
                            .foregroundColor(AztecTheme.hotPink)

                        Button("LOCK") {
                            cloudService.accessLevel = .viewOnly
                            dismiss()
                        }
                        .buttonStyle(AztecButtonStyle(color: AztecTheme.hotPink))
                    } else {
                        HStack(spacing: 16) {
                            ForEach(0..<pinLength, id: \.self) { index in
                                Circle()
                                    .fill(index < enteredPIN.count ? AztecTheme.neonYellow : AztecTheme.hotPink.opacity(0.3))
                                    .frame(width: 20, height: 20)
                                    .shadow(color: index < enteredPIN.count ? AztecTheme.neonYellow.opacity(0.5) : .clear, radius: 4)
                            }
                        }
                        .modifier(ShakeModifier(offset: shakeOffset))

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                            ForEach(1...9, id: \.self) { number in
                                PinButton(number: "\(number)") {
                                    appendDigit("\(number)")
                                }
                            }
                            PinButton(number: "") { }
                                .opacity(0)
                            PinButton(number: "0") {
                                appendDigit("0")
                            }
                            PinButton(number: "⌫") {
                                if !enteredPIN.isEmpty {
                                    enteredPIN.removeLast()
                                }
                            }
                        }
                        .padding(.horizontal, 40)
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .dismissButtonStyle()
                }
            }
        }
    }

    private func appendDigit(_ digit: String) {
        guard enteredPIN.count < pinLength else { return }
        enteredPIN += digit

        if enteredPIN.count == pinLength {
            validatePIN()
        }
    }

    private func validatePIN() {
        if enteredPIN == adminCode {
            cloudService.accessLevel = .admin
            dismiss()
        } else if enteredPIN == scorekeeperCode {
            cloudService.accessLevel = .scorekeeper
            dismiss()
        } else {
            showError = true
            withAnimation(.default) {
                shakeOffset = 10
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.default) {
                    shakeOffset = -10
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.default) {
                    shakeOffset = 10
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.default) {
                    shakeOffset = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                enteredPIN = ""
                showError = false
            }
        }
    }
}

struct PinButton: View {
    let number: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(number)
                .font(AztecTheme.sfProBold(size: 28))
                .foregroundColor(AztecTheme.neonYellow)
                .frame(width: 72, height: 72)
                .background(
                    Circle()
                        .fill(Color.black)
                        .overlay(
                            Circle()
                                .stroke(AztecTheme.hotPink.opacity(0.5), lineWidth: 2.25)
                        )
                )
        }
    }
}

struct ShakeModifier: ViewModifier {
    var offset: CGFloat

    func body(content: Content) -> some View {
        content.offset(x: offset)
    }
}
