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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .bold))
                        Text(tab.rawValue)
                            .font(AztecTheme.handwritten(size: 11))
                    }
                    .foregroundColor(selectedTab == tab ? AztecTheme.gold : AztecTheme.stone)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == tab ?
                        AztecTheme.gold.opacity(0.15) :
                        Color.clear
                    )
                    .overlay(alignment: .top) {
                        if selectedTab == tab {
                            AztecTheme.glowingLine
                                .frame(height: 2)
                        }
                    }
                }
            }
        }
        .background(AztecTheme.obsidian.opacity(0.95))
        .overlay(alignment: .top) {
            AztecTheme.borderLine
        }
    }
}
