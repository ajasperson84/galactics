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

        var highlightColor: Color {
            switch self {
            case .tournament: return AztecTheme.gold
            case .teams: return AztecTheme.jade
            case .players: return AztecTheme.amber
            case .stats: return AztecTheme.cosmic
            }
        }
    }

    var body: some View {
        ZStack {
            AztecBackground()

            VStack(spacing: 0) {
                // Header
                AztecHeader(title: "G FOUR")

                // Content
                TabView(selection: $selectedTab) {
                    TournamentView()
                        .tag(AppTab.tournament)

                    TeamsView()
                        .tag(AppTab.teams)

                    PlayersView()
                        .tag(AppTab.players)

                    StatsView()
                        .tag(AppTab.stats)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

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
                            .font(.system(size: 18, weight: .bold))
                        Text(tab.rawValue)
                            .font(AztecTheme.impact(size: 10))
                            .tracking(0.5)
                    }
                    .foregroundColor(AztecTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == tab
                            ? tab.highlightColor.opacity(0.4)
                            : Color.clear
                    )
                }
            }
        }
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AztecTheme.ink)
                .frame(height: 1.5)
        }
    }
}
