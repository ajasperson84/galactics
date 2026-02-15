import SwiftUI

struct TeamsView: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @State private var showingAddTeam = false
    @State private var selectedTeam: Team?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Add team button
                HStack {
                    Spacer()
                    Button {
                        showingAddTeam = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("NEW TEAM")
                        }
                    }
                    .buttonStyle(AztecButtonStyle())
                }
                .padding(.horizontal)

                AztecSectionHeader(title: "\(cloudService.teams.count) Teams")
                    .padding(.horizontal)

                // Teams
                LazyVStack(spacing: 12) {
                    ForEach(cloudService.teams) { team in
                        TeamCard(team: team)
                            .onTapGesture {
                                selectedTeam = team
                            }
                    }
                }
                .padding(.horizontal)

                // Unassigned players
                let unassigned = cloudService.unassignedPlayers()
                if !unassigned.isEmpty {
                    AztecSectionHeader(title: "\(unassigned.count) Free Agents", color: AztecTheme.jade)
                        .padding(.horizontal)

                    LazyVStack(spacing: 8) {
                        ForEach(unassigned) { player in
                            FreeAgentRow(player: player)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 16)
        }
        .sheet(isPresented: $showingAddTeam) {
            AddTeamSheet()
        }
        .sheet(item: $selectedTeam) { team in
            TeamDetailSheet(team: team)
        }
    }
}

struct TeamCard: View {
    @EnvironmentObject var cloudService: CloudSyncService
    let team: Team

    var teamPlayers: [Player] {
        cloudService.playersForTeam(team.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Team emblem
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AztecTheme.gold.opacity(0.15))
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AztecTheme.gold.opacity(0.4), lineWidth: 1)
                        )

                    Text(String(team.name.prefix(2)).uppercased())
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(AztecTheme.gold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(team.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AztecTheme.lightText)

                    Text("\(teamPlayers.count) players")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AztecTheme.dimText)
                }

                Spacer()

                // Win-Loss record
                VStack(spacing: 2) {
                    Text("\(team.wins)-\(team.losses)")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(AztecTheme.gold)

                    Text("W-L")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(AztecTheme.dimText)
                }
            }

            // Player chips
            if !teamPlayers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(teamPlayers) { player in
                            Text(player.name)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AztecTheme.jade)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(AztecTheme.jade.opacity(0.1))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(AztecTheme.jade.opacity(0.2), lineWidth: 0.5)
                                )
                        }
                    }
                }
            }
        }
        .aztecCard()
    }
}

struct FreeAgentRow: View {
    @EnvironmentObject var cloudService: CloudSyncService
    let player: Player
    @State private var showTeamPicker = false

    var body: some View {
        HStack {
            Text(player.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AztecTheme.lightText)

            Spacer()

            Button("ASSIGN") {
                showTeamPicker = true
            }
            .buttonStyle(AztecSecondaryButtonStyle(color: AztecTheme.jade))
        }
        .padding(12)
        .background(AztecTheme.darkStone)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .sheet(isPresented: $showTeamPicker) {
            TeamPickerSheet(player: player)
        }
    }
}

struct TeamPickerSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    let player: Player

    var body: some View {
        NavigationStack {
            ZStack {
                AztecTheme.obsidian.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 8) {
                        AztecSectionHeader(title: "Assign \(player.name)")

                        ForEach(cloudService.teams) { team in
                            Button {
                                Task {
                                    await cloudService.assignPlayerToTeam(
                                        playerId: player.id,
                                        teamId: team.id
                                    )
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Text(team.name)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AztecTheme.lightText)

                                    Spacer()

                                    Text("\(cloudService.playersForTeam(team.id).count) players")
                                        .font(.system(size: 12))
                                        .foregroundColor(AztecTheme.dimText)
                                }
                                .padding(14)
                                .background(AztecTheme.darkStone)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Pick Team")
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

struct AddTeamSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    @State private var teamName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AztecTheme.obsidian.ignoresSafeArea()

                VStack(spacing: 24) {
                    AztecSectionHeader(title: "Create Team")

                    TextField("Team Name", text: $teamName)
                        .aztecTextField()

                    Button("CREATE TEAM") {
                        guard !teamName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        Task {
                            await cloudService.addTeam(
                                name: teamName.trimmingCharacters(in: .whitespaces)
                            )
                            dismiss()
                        }
                    }
                    .buttonStyle(AztecButtonStyle())
                    .disabled(teamName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("New Team")
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

struct TeamDetailSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    let team: Team
    @State private var editedName: String = ""
    @State private var showDeleteConfirm = false
    @State private var showAddPlayerPicker = false

    var teamPlayers: [Player] {
        cloudService.playersForTeam(team.id)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AztecTheme.obsidian.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Team emblem large
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AztecTheme.gold.opacity(0.12))
                                .frame(width: 90, height: 90)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AztecTheme.gold.opacity(0.4), lineWidth: 2)
                                )
                                .shadow(color: AztecTheme.gold.opacity(0.2), radius: 12)

                            Text(String(team.name.prefix(2)).uppercased())
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(AztecTheme.gold)
                        }

                        // Name edit
                        TextField("Team Name", text: $editedName)
                            .aztecTextField()
                            .multilineTextAlignment(.center)

                        // Record
                        HStack(spacing: 24) {
                            VStack {
                                Text("\(team.wins)")
                                    .font(.system(size: 28, weight: .black, design: .monospaced))
                                    .foregroundColor(AztecTheme.jade)
                                Text("WINS")
                                    .font(.system(size: 10, weight: .heavy))
                                    .tracking(2)
                                    .foregroundColor(AztecTheme.dimText)
                            }

                            Rectangle()
                                .fill(AztecTheme.stone.opacity(0.3))
                                .frame(width: 1, height: 40)

                            VStack {
                                Text("\(team.losses)")
                                    .font(.system(size: 28, weight: .black, design: .monospaced))
                                    .foregroundColor(AztecTheme.bloodRed)
                                Text("LOSSES")
                                    .font(.system(size: 10, weight: .heavy))
                                    .tracking(2)
                                    .foregroundColor(AztecTheme.dimText)
                            }
                        }
                        .aztecCard(highlight: AztecTheme.jade)

                        // Roster
                        HStack {
                            AztecSectionHeader(title: "Roster")
                            Spacer()
                            Button {
                                showAddPlayerPicker = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(AztecTheme.gold)
                            }
                        }

                        ForEach(teamPlayers) { player in
                            HStack {
                                Text(player.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AztecTheme.lightText)

                                Spacer()

                                Text(String(format: ".%03d", Int(player.stats.battingAverage * 1000)))
                                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                    .foregroundColor(AztecTheme.jade)

                                Button {
                                    Task {
                                        await cloudService.assignPlayerToTeam(
                                            playerId: player.id,
                                            teamId: nil
                                        )
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(AztecTheme.bloodRed.opacity(0.6))
                                }
                            }
                            .padding(10)
                            .background(AztecTheme.darkStone)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        // Save
                        Button("SAVE CHANGES") {
                            Task {
                                var updated = team
                                updated.name = editedName
                                await cloudService.updateTeam(updated)
                                dismiss()
                            }
                        }
                        .buttonStyle(AztecButtonStyle())

                        Button("DELETE TEAM") {
                            showDeleteConfirm = true
                        }
                        .buttonStyle(AztecSecondaryButtonStyle(color: AztecTheme.bloodRed))
                    }
                    .padding()
                }
            }
            .navigationTitle("Team Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AztecTheme.gold)
                }
            }
            .alert("Delete Team?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task {
                        await cloudService.deleteTeam(team)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will delete \(team.name). Players will become free agents.")
            }
            .sheet(isPresented: $showAddPlayerPicker) {
                AddPlayerToTeamSheet(team: team)
            }
            .onAppear {
                editedName = team.name
            }
        }
    }
}

struct AddPlayerToTeamSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    let team: Team

    var availablePlayers: [Player] {
        cloudService.players.filter { $0.teamId != team.id }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AztecTheme.obsidian.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 8) {
                        AztecSectionHeader(title: "Add to \(team.name)")

                        if availablePlayers.isEmpty {
                            Text("No available players")
                                .foregroundColor(AztecTheme.dimText)
                                .padding(.top, 40)
                        }

                        ForEach(availablePlayers) { player in
                            Button {
                                Task {
                                    await cloudService.assignPlayerToTeam(
                                        playerId: player.id,
                                        teamId: team.id
                                    )
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Text(player.name)
                                        .foregroundColor(AztecTheme.lightText)

                                    Spacer()

                                    if let currentTeamId = player.teamId,
                                       let currentTeam = cloudService.team(for: currentTeamId) {
                                        Text(currentTeam.name)
                                            .font(.system(size: 12))
                                            .foregroundColor(AztecTheme.dimText)
                                    } else {
                                        Text("Free Agent")
                                            .font(.system(size: 12))
                                            .foregroundColor(AztecTheme.jade)
                                    }
                                }
                                .padding(14)
                                .background(AztecTheme.darkStone)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .padding()
                }
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
