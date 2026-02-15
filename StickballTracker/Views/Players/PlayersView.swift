import SwiftUI

struct PlayersView: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @State private var showingAddPlayer = false
    @State private var searchText = ""
    @State private var selectedPlayer: Player?

    var filteredPlayers: [Player] {
        if searchText.isEmpty {
            return cloudService.players
        }
        return cloudService.players.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Search & Add
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AztecTheme.stone)
                        TextField("Search players...", text: $searchText)
                            .foregroundColor(AztecTheme.lightText)
                    }
                    .aztecTextField()

                    Button {
                        showingAddPlayer = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .buttonStyle(AztecButtonStyle())
                }
                .padding(.horizontal)

                // Player count
                AztecSectionHeader(title: "\(filteredPlayers.count) Players")
                    .padding(.horizontal)

                // Player list
                LazyVStack(spacing: 8) {
                    ForEach(filteredPlayers) { player in
                        PlayerRow(player: player)
                            .onTapGesture {
                                selectedPlayer = player
                            }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 16)
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerSheet()
        }
        .sheet(item: $selectedPlayer) { player in
            PlayerDetailSheet(player: player)
        }
    }
}

struct PlayerRow: View {
    @EnvironmentObject var cloudService: CloudSyncService
    let player: Player

    var teamName: String {
        if let teamId = player.teamId {
            return cloudService.team(for: teamId)?.name ?? "Unknown"
        }
        return "Free Agent"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(AztecTheme.darkStone)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(
                                player.teamId != nil
                                    ? AztecTheme.gold.opacity(0.4)
                                    : AztecTheme.stone.opacity(0.3),
                                lineWidth: 1
                            )
                    )

                Text(String(player.name.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(AztecTheme.gold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AztecTheme.lightText)

                Text(teamName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AztecTheme.dimText)
            }

            Spacer()

            // Quick stats
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: ".%03d", Int(player.stats.battingAverage * 1000)))
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundColor(AztecTheme.jade)

                Text("\(player.stats.gamesPlayed) GP")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(AztecTheme.dimText)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AztecTheme.stone)
        }
        .aztecCard()
    }
}

struct AddPlayerSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    @State private var playerName = ""
    @State private var selectedTeamId: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AztecTheme.obsidian.ignoresSafeArea()

                VStack(spacing: 24) {
                    AztecSectionHeader(title: "New Player")

                    TextField("Player Name", text: $playerName)
                        .aztecTextField()

                    AztecSectionHeader(title: "Assign to Team", color: AztecTheme.jade)

                    // Team picker
                    ScrollView {
                        VStack(spacing: 8) {
                            // Free agent option
                            Button {
                                selectedTeamId = nil
                            } label: {
                                HStack {
                                    Text("Free Agent")
                                        .foregroundColor(AztecTheme.lightText)
                                    Spacer()
                                    if selectedTeamId == nil {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AztecTheme.jade)
                                    }
                                }
                                .padding(12)
                                .background(
                                    selectedTeamId == nil
                                        ? AztecTheme.jade.opacity(0.1)
                                        : AztecTheme.darkStone
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }

                            ForEach(cloudService.teams) { team in
                                Button {
                                    selectedTeamId = team.id
                                } label: {
                                    HStack {
                                        Text(team.name)
                                            .foregroundColor(AztecTheme.lightText)
                                        Spacer()
                                        if selectedTeamId == team.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(AztecTheme.gold)
                                        }
                                    }
                                    .padding(12)
                                    .background(
                                        selectedTeamId == team.id
                                            ? AztecTheme.gold.opacity(0.1)
                                            : AztecTheme.darkStone
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                    }

                    Spacer()

                    Button("ADD PLAYER") {
                        guard !playerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        Task {
                            await cloudService.addPlayer(
                                name: playerName.trimmingCharacters(in: .whitespaces),
                                teamId: selectedTeamId
                            )
                            dismiss()
                        }
                    }
                    .buttonStyle(AztecButtonStyle())
                    .disabled(playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
            }
            .navigationTitle("Add Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AztecTheme.gold)
                }
            }
        }
    }
}

struct PlayerDetailSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    let player: Player
    @State private var editedName: String = ""
    @State private var selectedTeamId: String?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                AztecTheme.obsidian.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Player avatar
                        ZStack {
                            Circle()
                                .fill(AztecTheme.darkStone)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Circle()
                                        .stroke(AztecTheme.gold.opacity(0.5), lineWidth: 2)
                                )
                                .shadow(color: AztecTheme.gold.opacity(0.2), radius: 12)

                            Text(String(player.name.prefix(1)).uppercased())
                                .font(.system(size: 32, weight: .black))
                                .foregroundColor(AztecTheme.gold)
                        }

                        // Name edit
                        TextField("Name", text: $editedName)
                            .aztecTextField()
                            .multilineTextAlignment(.center)

                        // Team assignment
                        AztecSectionHeader(title: "Team Assignment", color: AztecTheme.jade)

                        Picker("Team", selection: $selectedTeamId) {
                            Text("Free Agent").tag(String?.none)
                            ForEach(cloudService.teams) { team in
                                Text(team.name).tag(String?.some(team.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AztecTheme.gold)

                        // Stats display
                        AztecSectionHeader(title: "Career Stats")
                        PlayerStatsGrid(stats: player.stats)

                        // Save button
                        Button("SAVE CHANGES") {
                            Task {
                                var updated = player
                                updated.name = editedName
                                if updated.teamId != selectedTeamId {
                                    await cloudService.assignPlayerToTeam(
                                        playerId: player.id,
                                        teamId: selectedTeamId
                                    )
                                }
                                updated.teamId = selectedTeamId
                                await cloudService.updatePlayer(updated)
                                dismiss()
                            }
                        }
                        .buttonStyle(AztecButtonStyle())

                        // Delete button
                        Button("DELETE PLAYER") {
                            showDeleteConfirm = true
                        }
                        .buttonStyle(AztecSecondaryButtonStyle(color: AztecTheme.bloodRed))
                    }
                    .padding()
                }
            }
            .navigationTitle("Player Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AztecTheme.gold)
                }
            }
            .alert("Delete Player?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task {
                        await cloudService.deletePlayer(player)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently remove \(player.name) and all their stats.")
            }
            .onAppear {
                editedName = player.name
                selectedTeamId = player.teamId
            }
        }
    }
}

struct PlayerStatsGrid: View {
    let stats: PlayerStats

    private var statItems: [(label: String, value: String)] {
        [
            ("GP", "\(stats.gamesPlayed)"),
            ("AB", "\(stats.atBats)"),
            ("H", "\(stats.hits)"),
            ("AVG", String(format: ".%03d", Int(stats.battingAverage * 1000))),
            ("1B", "\(stats.singles)"),
            ("2B", "\(stats.doubles)"),
            ("3B", "\(stats.triples)"),
            ("HR", "\(stats.homeRuns)"),
            ("R", "\(stats.runs)"),
            ("RBI", "\(stats.rbi)"),
            ("BB", "\(stats.walks)"),
            ("K", "\(stats.strikeouts)"),
            ("SLG", String(format: ".%03d", Int(stats.sluggingPercentage * 1000))),
            ("OBP", String(format: ".%03d", Int(stats.onBasePercentage * 1000))),
        ]
    }

    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(statItems, id: \.label) { item in
                VStack(spacing: 4) {
                    Text(item.value)
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .foregroundColor(AztecTheme.jade)

                    Text(item.label)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(AztecTheme.dimText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AztecTheme.darkStone)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AztecTheme.jade.opacity(0.15), lineWidth: 0.5)
                )
            }
        }
    }
}
