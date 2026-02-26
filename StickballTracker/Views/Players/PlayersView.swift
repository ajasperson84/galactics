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
                        TextField("Search ballers...", text: $searchText)
                            .foregroundColor(AztecTheme.lightText)
                    }
                    .aztecTextField()

                    // Parallelogram + button
                    Button {
                        showingAddPlayer = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .italic()
                            .foregroundColor(Color.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(AztecTheme.neonYellow)
                            .clipShape(ParallelogramShape(slant: 0.18))
                            .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 6)
                    }
                }
                .padding(.horizontal)

                // Player list
                LazyVStack(spacing: 8) {
                    ForEach(Array(filteredPlayers.enumerated()), id: \.element.id) { index, player in
                        PlayerRow(player: player, colorIndex: index)
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
    var colorIndex: Int = 0

    var teamName: String {
        if let teamId = player.teamId {
            return cloudService.team(for: teamId)?.name ?? "Unknown"
        }
        return "Free Agent"
    }

    private var playerTeam: Team? {
        if let teamId = player.teamId {
            return cloudService.team(for: teamId)
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            // Team icon instead of letter avatar
            if let team = playerTeam {
                TeamIconView(team: team, size: 44)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(AztecTheme.darkStone)
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(AztecTheme.hotPink.opacity(0.3), lineWidth: 1)
                        )
                    Text("FA")
                        .font(AztecTheme.impact(size: 14))
                        .foregroundColor(AztecTheme.dimText)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(AztecTheme.hobbsFont(size: 24))
                    .foregroundColor(AztecTheme.lightText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(teamName)
                    .font(AztecTheme.hobbsFont(size: 16))
                    .foregroundColor(AztecTheme.dimText)
                    .lineLimit(1)
            }

            Spacer()

            // Quick stats — dong numbers and "Dongs" stay yellow
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(player.stats.dongs) Dongs")
                    .font(AztecTheme.typewriterBold(size: 14))
                    .foregroundColor(AztecTheme.neonYellow)
                    .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 3)

                Text("\(player.stats.gamesPlayed) GP")
                    .font(AztecTheme.typewriter(size: 11))
                    .foregroundColor(AztecTheme.dimText)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold)).italic()
                .foregroundColor(AztecTheme.stone)
        }
        .padding(16)
        .neonCard(glow: 0.5)
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
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    AztecSectionHeader(title: "New Baller", shapeIndex: 0)

                    TextField("Baller Name", text: $playerName)
                        .aztecTextField()

                    AztecSectionHeader(title: "Assign to Squad", color: AztecTheme.jade, shapeIndex: 1)

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
                                        ? AztecTheme.jade.opacity(0.08)
                                        : AztecTheme.darkStone
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            selectedTeamId == nil
                                                ? AztecTheme.jade.opacity(0.3)
                                                : AztecTheme.hotPink.opacity(0.15),
                                            lineWidth: 1
                                        )
                                )
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
                                                .foregroundColor(AztecTheme.neonYellow)
                                        }
                                    }
                                    .padding(12)
                                    .background(
                                        selectedTeamId == team.id
                                            ? AztecTheme.neonYellow.opacity(0.06)
                                            : AztecTheme.darkStone
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                selectedTeamId == team.id
                                                    ? AztecTheme.neonYellow.opacity(0.3)
                                                    : AztecTheme.hotPink.opacity(0.15),
                                                lineWidth: 1
                                            )
                                    )
                                }
                            }
                        }
                    }

                    Spacer()

                    Button("ADD BALLER") {
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
            .navigationTitle("Add Baller")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AztecTheme.neonYellow)
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
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Player avatar
                        ZStack {
                            Circle()
                                .fill(AztecTheme.darkStone)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Circle()
                                        .stroke(AztecTheme.hotPink, lineWidth: 1.5)
                                )
                                .shadow(color: AztecTheme.hotPink.opacity(0.3), radius: 8)

                            Text(String(player.name.prefix(1)).uppercased())
                                .font(AztecTheme.hobbsFont(size: 40))
                                .foregroundColor(AztecTheme.neonYellow)
                        }

                        // Name edit
                        TextField("Name", text: $editedName)
                            .aztecTextField()
                            .multilineTextAlignment(.center)

                        // Team assignment
                        AztecSectionHeader(title: "Squad Assignment", color: AztecTheme.jade, shapeIndex: 2)

                        Picker("Team", selection: $selectedTeamId) {
                            Text("Free Agent").tag(String?.none)
                            ForEach(cloudService.teams) { team in
                                Text(team.name).tag(String?.some(team.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AztecTheme.neonYellow)

                        // Stats display
                        AztecSectionHeader(title: "Career Stats", shapeIndex: 3)
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
                        Button("DELETE BALLER") {
                            showDeleteConfirm = true
                        }
                        .buttonStyle(AztecSecondaryButtonStyle(color: AztecTheme.bloodRed))
                    }
                    .padding()
                }
            }
            .navigationTitle("Baller Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AztecTheme.neonYellow)
                }
            }
            .alert("Delete Baller?", isPresented: $showDeleteConfirm) {
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
            ("Dongs", "\(stats.dongs)"),
            ("Salamies", "\(stats.salamies)"),
            ("Dbl Plays", "\(stats.doublePlays)"),
            ("Drops", "\(stats.drops)"),
            ("Suds", "\(stats.suds)"),
            ("Tacos", "\(stats.tacos)"),
        ]
    }

    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(statItems, id: \.label) { item in
                VStack(spacing: 4) {
                    Text(item.value)
                        .font(AztecTheme.typewriterBold(size: 18))
                        .foregroundColor(AztecTheme.jade)
                        .shadow(color: AztecTheme.jade.opacity(0.3), radius: 3)

                    Text(item.label)
                        .font(AztecTheme.impact(size: 10))
                        .tracking(1)
                        .foregroundColor(AztecTheme.dimText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AztecTheme.darkStone)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AztecTheme.hotPink.opacity(0.15), lineWidth: 0.5)
                )
            }
        }
    }
}
