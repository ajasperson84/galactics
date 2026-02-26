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
                            Text("NEW SQUAD")
                        }
                        .font(AztecTheme.jazzFont(size: 10))
                        .tracking(2)
                        .foregroundColor(Color.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(AztecTheme.neonYellow)
                        .clipShape(TrapezoidShape(skew: 0.12))
                        .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 6)
                    }
                }
                .padding(.horizontal)

                // Teams
                LazyVStack(spacing: 12) {
                    ForEach(Array(cloudService.teams.enumerated()), id: \.element.id) { index, team in
                        TeamCard(team: team, colorIndex: index)
                            .onTapGesture {
                                selectedTeam = team
                            }
                    }
                }
                .padding(.horizontal)

                // Unassigned players
                let unassigned = cloudService.unassignedPlayers()
                if !unassigned.isEmpty {
                    AztecSectionHeader(title: "\(unassigned.count) Free Agents", color: AztecTheme.jade, shapeIndex: 1)
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
    var colorIndex: Int = 0

    var teamPlayers: [Player] {
        cloudService.playersForTeam(team.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TeamIconView(team: team, size: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(team.name)
                        .font(AztecTheme.hobbsFont(size: 30))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundColor(AztecTheme.neonYellow)
                        .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 3)

                    Text("\(teamPlayers.count) ballers")
                        .font(AztecTheme.typewriter(size: 12))
                        .lineLimit(1)
                        .foregroundColor(AztecTheme.dimText)
                }

                Spacer()

                // Aggregated team dongs
                VStack(spacing: 2) {
                    let totalDongs = teamPlayers.reduce(0) { $0 + $1.stats.dongs }
                    Text("\(totalDongs)")
                        .font(AztecTheme.typewriterBold(size: 22))
                        .foregroundColor(AztecTheme.neonYellow)
                        .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 3)

                    Text("DONGS")
                        .font(AztecTheme.impact(size: 10))
                        .tracking(1)
                        .foregroundColor(AztecTheme.neonYellow.opacity(0.7))
                }
            }

            // Player names
            if !teamPlayers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(teamPlayers) { player in
                            Text(player.name)
                                .font(AztecTheme.hobbsFont(size: 18))
                                .foregroundColor(AztecTheme.lightText)
                        }
                    }
                }
            }
        }
        .padding(16)
        .neonCard()
    }
}

struct FreeAgentRow: View {
    @EnvironmentObject var cloudService: CloudSyncService
    let player: Player
    @State private var showTeamPicker = false

    var body: some View {
        HStack {
            Text(player.name)
                .font(AztecTheme.hobbsFont(size: 22))
                .foregroundColor(AztecTheme.lightText)

            Spacer()

            Button("ASSIGN") {
                showTeamPicker = true
            }
            .buttonStyle(AztecSecondaryButtonStyle(color: AztecTheme.jade))
        }
        .padding(12)
        .background(AztecTheme.darkStone)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AztecTheme.hotPink.opacity(0.3), lineWidth: 1)
        )
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
                Color.black.ignoresSafeArea()

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
                                        .font(AztecTheme.hobbsFont(size: 28))
                                        .foregroundColor(AztecTheme.lightText)

                                    Spacer()

                                    Text("\(cloudService.playersForTeam(team.id).count) ballers")
                                        .font(AztecTheme.typewriter(size: 12))
                                        .foregroundColor(AztecTheme.dimText)
                                }
                                .padding(14)
                                .background(AztecTheme.darkStone)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AztecTheme.hotPink.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Pick Squad")
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

struct AddTeamSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    @State private var teamName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    AztecSectionHeader(title: "Create Squad")

                    TextField("Squad Name", text: $teamName)
                        .aztecTextField()

                    Button("CREATE SQUAD") {
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
            .navigationTitle("New Squad")
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

struct TeamDetailSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    let team: Team
    @State private var editedName: String = ""
    @State private var editedIconName: String = ""
    @State private var showDeleteConfirm = false
    @State private var showAddPlayerPicker = false

    var teamPlayers: [Player] {
        cloudService.playersForTeam(team.id)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Team icon large
                        TeamIconView(team: team, size: 90)
                            .shadow(color: AztecTheme.hotPink.opacity(0.3), radius: 12)

                        // Name edit
                        TextField("Team Name", text: $editedName)
                            .aztecTextField()
                            .multilineTextAlignment(.center)

                        // Icon name edit
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ICON NAME")
                                .font(AztecTheme.impact(size: 10))
                                .tracking(2)
                                .foregroundColor(AztecTheme.dimText)
                            TextField("Asset name (e.g. team-rosecity)", text: $editedIconName)
                                .aztecTextField()
                        }

                        // Squad stats summary
                        let totalDongs = teamPlayers.reduce(0) { $0 + $1.stats.dongs }
                        let totalSalamies = teamPlayers.reduce(0) { $0 + $1.stats.salamies }
                        let totalDP = teamPlayers.reduce(0) { $0 + $1.stats.doublePlays }
                        let totalSuds = teamPlayers.reduce(0) { $0 + $1.stats.suds }
                        let totalTacos = teamPlayers.reduce(0) { $0 + $1.stats.tacos }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            StatBubble(value: totalDongs, label: "DONGS", color: AztecTheme.neonYellow)
                            StatBubble(value: totalSalamies, label: "SALAMIES", color: AztecTheme.jade)
                            StatBubble(value: totalDP, label: "DBL PLAYS", color: AztecTheme.hotPink)
                            StatBubble(value: totalSuds, label: "SUDS", color: AztecTheme.cosmic)
                            StatBubble(value: totalTacos, label: "TACOS", color: AztecTheme.tennisGreen)
                        }
                        .aztecCard(highlight: AztecTheme.hotPink)

                        // Roster
                        HStack {
                            AztecSectionHeader(title: "Roster")
                            Spacer()
                            Button {
                                showAddPlayerPicker = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(AztecTheme.neonYellow)
                                    .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 3)
                            }
                        }

                        ForEach(teamPlayers) { player in
                            HStack {
                                Text(player.name)
                                    .font(AztecTheme.hobbsFont(size: 22))
                                    .foregroundColor(AztecTheme.lightText)

                                Spacer()

                                Text("\(player.stats.dongs) D")
                                    .font(AztecTheme.typewriterBold(size: 14))
                                    .foregroundColor(AztecTheme.neonYellow)

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
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AztecTheme.hotPink.opacity(0.15), lineWidth: 1)
                            )
                        }

                        // Save
                        Button("SAVE CHANGES") {
                            Task {
                                var updated = team
                                updated.name = editedName
                                let trimmedIcon = editedIconName.trimmingCharacters(in: .whitespaces)
                                updated.iconName = trimmedIcon.isEmpty ? nil : trimmedIcon
                                await cloudService.updateTeam(updated)
                                dismiss()
                            }
                        }
                        .buttonStyle(AztecButtonStyle())

                        Button("DELETE SQUAD") {
                            showDeleteConfirm = true
                        }
                        .buttonStyle(AztecSecondaryButtonStyle(color: AztecTheme.bloodRed))
                    }
                    .padding()
                }
            }
            .navigationTitle("Squad Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AztecTheme.neonYellow)
                }
            }
            .alert("Delete Squad?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task {
                        await cloudService.deleteTeam(team)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will delete \(team.name). Ballers will become free agents.")
            }
            .sheet(isPresented: $showAddPlayerPicker) {
                AddPlayerToTeamSheet(team: team)
            }
            .onAppear {
                editedName = team.name
                editedIconName = team.iconName ?? ""
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
                Color.black.ignoresSafeArea()

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
                                }
                            } label: {
                                HStack {
                                    Text(player.name)
                                        .font(AztecTheme.hobbsFont(size: 24))
                                        .foregroundColor(AztecTheme.lightText)

                                    Spacer()

                                    if player.teamId == team.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AztecTheme.jade)
                                    } else if let currentTeamId = player.teamId,
                                       let currentTeam = cloudService.team(for: currentTeamId) {
                                        Text(currentTeam.name)
                                            .font(AztecTheme.typewriter(size: 12))
                                            .foregroundColor(AztecTheme.dimText)
                                    } else {
                                        Text("Free Agent")
                                            .font(AztecTheme.typewriter(size: 12))
                                            .foregroundColor(AztecTheme.jade)
                                    }
                                }
                                .padding(14)
                                .background(AztecTheme.darkStone)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AztecTheme.hotPink.opacity(0.15), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Ballers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AztecTheme.neonYellow)
                }
            }
        }
    }
}

struct StatBubble: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(AztecTheme.typewriterBold(size: 22))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.3), radius: 3)
            Text(label)
                .font(AztecTheme.impact(size: 8))
                .tracking(1)
                .foregroundColor(AztecTheme.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}
