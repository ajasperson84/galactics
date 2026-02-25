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
            case .players: return "person.fill"
            case .stats: return "chart.bar.fill"
            }
        }

        var backgroundColor: Color {
            switch self {
            case .tournament: return AztecTheme.tourneyBg
            case .teams: return AztecTheme.squadsBg
            case .players: return AztecTheme.ballersBg
            case .stats: return AztecTheme.statsBg
            }
        }

        var accentColor: Color {
            switch self {
            case .tournament: return AztecTheme.gold
            case .teams: return AztecTheme.jade
            case .players: return AztecTheme.amber
            case .stats: return AztecTheme.tennisGreen
            }
        }
    }

    var body: some View {
        ZStack {
            // Dynamic neon background per section
            selectedTab.backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: selectedTab)

            VStack(spacing: 0) {
                // Header
                AztecHeader(title: "G FOUR")

                // Content — manual switching fixes text field interactivity
                // (page-style TabView swipe gestures block TextField input)
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
                        Text(tab.rawValue)
                            .font(AztecTheme.jazzFont(size: 6))
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(TabBarButtonStyle(isSelected: selectedTab == tab))
            }
        }
        .background(AztecTheme.tennisGreen)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AztecTheme.gold)
                .frame(height: 1)
        }
    }
}

/// Custom button style for tab bar: neon pink when pressed, neon orange when selected.
struct TabBarButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(
                isSelected ? Color.black :
                configuration.isPressed ? Color.black :
                AztecTheme.obsidian.opacity(0.6)
            )
            .background(
                isSelected ? AztecTheme.neonOrange :
                configuration.isPressed ? AztecTheme.neonPink :
                Color.clear
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
