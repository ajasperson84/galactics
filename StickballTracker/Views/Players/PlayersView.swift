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
                            .foregroundColor(AztecTheme.hotPink)
                        TextField("Search ballers...", text: $searchText)
                            .foregroundColor(AztecTheme.lightText)
                    }
                    .aztecTextField()

                    // Pink plus in yellow circle (add baller button)
                    if cloudService.accessLevel == .admin {
                        Button {
                            showingAddPlayer = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(AztecTheme.neonYellow)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 6)

                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(AztecTheme.hotPink)
                            }
                        }
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
            // Team icon
            if let team = playerTeam {
                TeamIconView(team: team, size: 44)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.black)
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(AztecTheme.hotPink.opacity(0.5), lineWidth: 2.25)
                        )
                    Text("FA")
                        .font(AztecTheme.sfProBold(size: 14))
                        .foregroundColor(AztecTheme.hotPink)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                // Player name — 2x large
                Text(player.name)
                    .font(AztecTheme.hobbsFont(size: 44))
                    .tracking(AztecTheme.hobbsKerning)
                    .foregroundColor(AztecTheme.neonYellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)

                Text(teamName)
                    .font(AztecTheme.sfProBold(size: 14))
                    .foregroundColor(AztecTheme.hotPink)
                    .lineLimit(1)
            }

            Spacer()

            // Dongs — half size (reduced)
            Text("\(player.stats.dongs) D")
                .font(AztecTheme.sfProBold(size: 14))
                .foregroundColor(AztecTheme.neonYellow)
                .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 3)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AztecTheme.hotPink)
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
                    AztecSectionHeader(title: "New Baller")

                    TextField("Baller Name", text: $playerName)
                        .aztecTextField()

                    AztecSectionHeader(title: "Assign to Squad", color: AztecTheme.hotPink)

                    // Team picker
                    ScrollView {
                        VStack(spacing: 8) {
                            // Free agent option
                            Button {
                                selectedTeamId = nil
                            } label: {
                                HStack {
                                    Text("Free Agent")
                                        .font(AztecTheme.sfProBold(size: 16))
                                        .foregroundColor(AztecTheme.neonYellow)
                                    Spacer()
                                    if selectedTeamId == nil {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AztecTheme.neonYellow)
                                    }
                                }
                                .padding(12)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            selectedTeamId == nil
                                                ? AztecTheme.neonYellow
                                                : AztecTheme.hotPink.opacity(0.3),
                                            lineWidth: 2.25
                                        )
                                )
                            }

                            ForEach(cloudService.teams) { team in
                                Button {
                                    selectedTeamId = team.id
                                } label: {
                                    HStack {
                                        Text(team.name)
                                            .font(AztecTheme.sfProBold(size: 16))
                                            .foregroundColor(AztecTheme.neonYellow)
                                        Spacer()
                                        if selectedTeamId == team.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(AztecTheme.neonYellow)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                selectedTeamId == team.id
                                                    ? AztecTheme.neonYellow
                                                    : AztecTheme.hotPink.opacity(0.3),
                                                lineWidth: 2.25
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
                        .dismissButtonStyle()
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

    private var playerTeam: Team? {
        if let teamId = player.teamId {
            return cloudService.team(for: teamId)
        }
        return nil
    }

    private var statItems: [(label: String, value: Int)] {
        [
            ("Dongs", player.stats.dongs),
            ("Salamies", player.stats.salamies),
            ("Dbl Plays", player.stats.doublePlays),
            ("Drops", player.stats.drops),
            ("Games", player.stats.gamesPlayed),
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Player icon — use team icon if assigned
                        if let team = playerTeam {
                            TeamIconView(team: team, size: 80, glowRadius: 6)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Circle()
                                            .stroke(AztecTheme.hotPink, lineWidth: 2.25)
                                    )
                                    .shadow(color: AztecTheme.hotPink.opacity(0.3), radius: 8)

                                Text(String(player.name.prefix(1)).uppercased())
                                    .font(AztecTheme.hobbsFont(size: 40))
                                    .tracking(AztecTheme.hobbsKerning)
                                    .foregroundColor(AztecTheme.neonYellow)
                            }
                        }

                        // Name edit — Hobbs font
                        TextField("Name", text: $editedName)
                            .font(AztecTheme.hobbsFont(size: 50))
                            .tracking(AztecTheme.hobbsKerning)
                            .foregroundColor(AztecTheme.neonYellow)
                            .multilineTextAlignment(.center)
                            .padding(12)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AztecTheme.hotPink.opacity(0.5), lineWidth: 2.25)
                            )

                        // Team assignment picker
                        if cloudService.accessLevel == .admin {
                            Text("SQUAD")
                                .font(AztecTheme.hobbsFont(size: 36))
                                .tracking(AztecTheme.hobbsKerning)
                                .foregroundColor(AztecTheme.hotPink)
                                .shadow(color: AztecTheme.hotPink.opacity(0.4), radius: 4)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Button {
                                        selectedTeamId = nil
                                    } label: {
                                        Text("Free Agent")
                                            .font(AztecTheme.sfProBold(size: 14))
                                            .foregroundColor(selectedTeamId == nil ? Color.black : AztecTheme.neonYellow)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(selectedTeamId == nil ? AztecTheme.neonYellow : Color.black)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(AztecTheme.neonYellow, lineWidth: 2.25)
                                            )
                                    }

                                    ForEach(cloudService.teams) { team in
                                        Button {
                                            selectedTeamId = team.id
                                        } label: {
                                            HStack(spacing: 6) {
                                                TeamIconView(team: team, size: 24, glowRadius: 2)
                                                Text(team.name)
                                                    .font(AztecTheme.sfProBold(size: 14))
                                                    .foregroundColor(selectedTeamId == team.id ? Color.black : AztecTheme.neonYellow)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(selectedTeamId == team.id ? AztecTheme.neonYellow : Color.black)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(
                                                        selectedTeamId == team.id ? AztecTheme.neonYellow : AztecTheme.hotPink.opacity(0.3),
                                                        lineWidth: 2.25
                                                    )
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        // Tourney Stats — each on its own line, 2x large, yellow with pink glow
                        Text("TOURNEY STATS")
                            .font(AztecTheme.hobbsFont(size: 36))
                            .tracking(AztecTheme.hobbsKerning)
                            .foregroundColor(AztecTheme.neonYellow)
                            .shadow(color: AztecTheme.hotPink.opacity(0.4), radius: 4)

                        VStack(spacing: 8) {
                            ForEach(statItems, id: \.label) { item in
                                HStack {
                                    Text(item.label)
                                        .font(AztecTheme.hobbsFont(size: 30))
                                        .tracking(AztecTheme.hobbsKerning)
                                        .foregroundColor(AztecTheme.hotPink)

                                    Spacer()

                                    Text("\(item.value)")
                                        .font(AztecTheme.sfProBold(size: 30))
                                        .foregroundColor(AztecTheme.neonYellow)
                                        .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 3)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 8)
                        .neonCard()

                        // Save button
                        if cloudService.accessLevel == .admin {
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
                            .buttonStyle(AztecButtonStyle(color: AztecTheme.hotPink))
                        }

                        // Delete button
                        if cloudService.accessLevel == .admin {
                            Button("DELETE BALLER") {
                                showDeleteConfirm = true
                            }
                            .buttonStyle(AztecSecondaryButtonStyle(color: AztecTheme.bloodRed))
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .dismissButtonStyle()
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
