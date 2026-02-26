import SwiftUI

struct ContentView: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @State private var selectedTab: AppTab = .tournament

    enum AppTab: String, CaseIterable {
        case tournament = "Tourney"
        case teams = "Squads"
        case players = "Ballers"
        case stats = "Stats"

        var icon: String {
            switch self {
            case .tournament: return "trophy.fill"
            case .teams: return "person.3.fill"
            case .players: return "tennisball.fill"
            case .stats: return "chart.bar.fill"
            }
        }

        var backgroundColor: Color {
            return Color.black
        }

        var accentColor: Color {
            switch self {
            case .tournament: return AztecTheme.neonYellow
            case .teams: return AztecTheme.hotPink
            case .players: return AztecTheme.jade
            case .stats: return AztecTheme.cosmic
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                AztecHeader(title: "G FOUR")

                // Content
                Group {
                    switch selectedTab {
                    case .tournament: TournamentView()
                    case .teams: TeamsView()
                    case .players: PlayersView()
                    case .stats: StatsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Custom tab bar
                AztecTabBar(selectedTab: $selectedTab)
            }
        }
    }
}

struct AztecTabBar: View {
    @Binding var selectedTab: ContentView.AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ContentView.AppTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .black))
                            .italic()
                        Text(tab.rawValue)
                            .font(AztecTheme.jazzFont(size: 6))
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(TabBarButtonStyle(
                    isSelected: selectedTab == tab,
                    accentColor: tab.accentColor
                ))
            }
        }
        .background(Color(white: 0.06))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AztecTheme.hotPink)
                .frame(height: 1)
                .shadow(color: AztecTheme.hotPink.opacity(0.5), radius: 3)
        }
    }
}

/// Tab bar button: neon accent when selected, dim when not.
struct TabBarButtonStyle: ButtonStyle {
    let isSelected: Bool
    var accentColor: Color = AztecTheme.hotPink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(
                isSelected ? accentColor :
                configuration.isPressed ? accentColor.opacity(0.7) :
                Color.white.opacity(0.4)
            )
            .background(
                isSelected ? accentColor.opacity(0.12) :
                configuration.isPressed ? accentColor.opacity(0.06) :
                Color.clear
            )
            .shadow(color: isSelected ? accentColor.opacity(0.3) : .clear, radius: 4)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
