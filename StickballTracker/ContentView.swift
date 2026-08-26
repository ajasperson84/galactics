import SwiftUI

struct ContentView: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @State private var selectedTab: AppTab = .tournament

    enum AppTab: String, CaseIterable {
        case tournament = "Tourney"
        case teams = "Squads"
        case stats = "Stats"

        var icon: String {
            switch self {
            case .tournament: return "trophy.fill"
            case .teams: return "person.3.fill"
            case .stats: return "chart.bar.fill"
            }
        }

        var backgroundColor: Color {
            return Color.black
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                AztecHeader()

                // Menu bar under header — text 2.5x larger
                HStack(spacing: 0) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTab = tab
                            }
                        } label: {
                            Text(tab.rawValue)
                                .font(AztecTheme.hobbsFont(size: 45))
                                .tracking(AztecTheme.hobbsKerning)
                                .foregroundColor(
                                    selectedTab == tab
                                        ? AztecTheme.hotPink
                                        : AztecTheme.neonYellow
                                )
                                .shadow(color: selectedTab == tab
                                        ? AztecTheme.hotPink.opacity(0.4) : .clear, radius: 3)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                        }
                    }
                }
                .background(Color.black)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(AztecTheme.hotPink.opacity(0.4))
                        .frame(height: 1)
                }

                // Content
                Group {
                    switch selectedTab {
                    case .tournament: TournamentView()
                    case .teams: TeamsView()
                    case .stats: StatsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom tab bar
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
                        ZStack {
                            if selectedTab == tab {
                                Circle()
                                    .fill(AztecTheme.hotPink)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: AztecTheme.hotPink.opacity(0.5), radius: 6)
                            }

                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(
                                    selectedTab == tab
                                        ? AztecTheme.neonYellow
                                        : Color.white.opacity(0.4)
                                )
                        }

                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(
                                selectedTab == tab
                                    ? AztecTheme.neonYellow
                                    : Color.white.opacity(0.4)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
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
