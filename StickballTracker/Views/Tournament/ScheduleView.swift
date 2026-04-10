import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var cloudService: CloudSyncService
    let tier: TournamentTier
    let tierIndex: Int
    var onTapGame: ((TournamentGame) -> Void)?
    @State private var showPinEntry = false

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

            // Lock button
            Spacer().frame(height: 8)
            Button {
                showPinEntry = true
            } label: {
                let isUnlocked = cloudService.accessLevel != .viewOnly
                HStack(spacing: 6) {
                    Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 16, weight: .bold))
                    if isUnlocked {
                        Text(cloudService.accessLevel == .admin ? "ADMIN" : "SCOREKEEPER")
                            .font(AztecTheme.sfProBold(size: 10))
                            .tracking(1)
                    }
                }
                .foregroundColor(isUnlocked ? AztecTheme.neonYellow : AztecTheme.hotPink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isUnlocked ? AztecTheme.neonYellow.opacity(0.5) : AztecTheme.hotPink.opacity(0.4),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: isUnlocked ? AztecTheme.neonYellow.opacity(0.3) : .clear, radius: 4)
            }
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showPinEntry) {
            PinEntrySheet()
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

// MARK: - PIN Entry Sheet

struct PinEntrySheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    @State private var enteredCode = ""
    @State private var errorFlash = false
    @State private var successMessage: String?

    private let scorekeeperCode = "5687"
    private let adminCode = "3255"

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Current access level
                    VStack(spacing: 4) {
                        Text("ACCESS LEVEL")
                            .font(AztecTheme.sfProBold(size: 11))
                            .tracking(2)
                            .foregroundColor(AztecTheme.hotPink)
                        Text(accessLevelLabel)
                            .font(AztecTheme.hobbsFont(size: 32))
                            .tracking(AztecTheme.hobbsKerning)
                            .foregroundColor(AztecTheme.neonYellow)
                            .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 4)
                    }
                    .padding(.top, 16)

                    if let msg = successMessage {
                        Text(msg)
                            .font(AztecTheme.sfProBold(size: 14))
                            .foregroundColor(AztecTheme.neonYellow)
                            .shadow(color: AztecTheme.neonYellow.opacity(0.5), radius: 4)
                            .transition(.opacity)
                    }

                    // PIN dots
                    HStack(spacing: 16) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(index < enteredCode.count ? AztecTheme.hotPink : AztecTheme.hotPink.opacity(0.2))
                                .frame(width: 16, height: 16)
                                .shadow(color: index < enteredCode.count ? AztecTheme.hotPink.opacity(0.6) : .clear, radius: 4)
                        }
                    }
                    .modifier(ShakeModifier(shake: errorFlash))

                    // Keypad
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 12) {
                        ForEach(1...9, id: \.self) { num in
                            pinButton("\(num)") { appendDigit("\(num)") }
                        }
                        pinButton("") { } // empty spacer
                            .opacity(0)
                        pinButton("0") { appendDigit("0") }
                        pinButton("delete.left.fill", isIcon: true) { deleteDigit() }
                    }
                    .padding(.horizontal, 40)

                    // Lock button if currently unlocked
                    if cloudService.accessLevel != .viewOnly {
                        Button {
                            withAnimation {
                                cloudService.accessLevel = .viewOnly
                                enteredCode = ""
                                successMessage = nil
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("LOCK")
                                    .font(AztecTheme.sfProBold(size: 14))
                                    .tracking(1)
                            }
                            .foregroundColor(AztecTheme.hotPink)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AztecTheme.hotPink.opacity(0.5), lineWidth: 1.5)
                            )
                        }
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

    private var accessLevelLabel: String {
        switch cloudService.accessLevel {
        case .viewOnly: return "VIEW ONLY"
        case .scorekeeper: return "SCOREKEEPER"
        case .admin: return "ADMIN"
        }
    }

    private func appendDigit(_ digit: String) {
        guard enteredCode.count < 4 else { return }
        enteredCode += digit
        if enteredCode.count == 4 {
            checkCode()
        }
    }

    private func deleteDigit() {
        if !enteredCode.isEmpty {
            enteredCode.removeLast()
        }
        successMessage = nil
    }

    private func checkCode() {
        if enteredCode == adminCode {
            withAnimation {
                cloudService.accessLevel = .admin
                successMessage = "ADMIN UNLOCKED"
            }
        } else if enteredCode == scorekeeperCode {
            withAnimation {
                cloudService.accessLevel = .scorekeeper
                successMessage = "SCOREKEEPER UNLOCKED"
            }
        } else {
            withAnimation(.default) {
                errorFlash.toggle()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                enteredCode = ""
            }
        }
    }

    private func pinButton(_ label: String, isIcon: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if isIcon {
                    Image(systemName: label)
                        .font(.system(size: 20, weight: .bold))
                } else {
                    Text(label)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                }
            }
            .foregroundColor(AztecTheme.neonYellow)
            .frame(width: 64, height: 64)
            .background(Color.black)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(AztecTheme.hotPink.opacity(0.4), lineWidth: 1.5)
            )
        }
    }
}

/// Shake animation modifier for wrong PIN
struct ShakeModifier: ViewModifier {
    var shake: Bool
    func body(content: Content) -> some View {
        content
            .offset(x: shake ? -6 : 0)
            .animation(.default.repeatCount(3, autoreverses: true).speed(6), value: shake)
    }
}
