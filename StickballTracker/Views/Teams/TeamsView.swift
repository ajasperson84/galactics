import SwiftUI

struct TeamsView: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @State private var showingAddTeam = false
    @State private var selectedTeam: Team?

    /// Teams sorted by record (best first), then by total dongs
    private var sortedTeams: [Team] {
        cloudService.teams.sorted { t1, t2 in
            let r1 = teamRecord(for: t1)
            let r2 = teamRecord(for: t2)
            if r1.wins != r2.wins { return r1.wins > r2.wins }
            if r1.losses != r2.losses { return r1.losses < r2.losses }
            return teamDongs(for: t1) > teamDongs(for: t2)
        }
    }

    private func teamRecord(for team: Team) -> (wins: Int, losses: Int) {
        guard let tournament = cloudService.tournament else { return (0, 0) }
        var wins = 0, losses = 0
        for tier in tournament.tiers {
            for game in tier.games where game.status == .completed {
                guard let winnerId = game.winnerId else { continue }
                if game.team1Id == team.id || game.team2Id == team.id {
                    if winnerId == team.id { wins += 1 } else { losses += 1 }
                }
            }
        }
        return (wins, losses)
    }

    private func teamDongs(for team: Team) -> Int {
        cloudService.playersForTeam(team.id).reduce(0) { $0 + $1.stats.dongs }
    }

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
                        .font(AztecTheme.sfProBold(size: 14))
                        .foregroundColor(AztecTheme.hotPink)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AztecTheme.hotPink, lineWidth: 2.25)
                        )
                        .shadow(color: AztecTheme.hotPink.opacity(0.3), radius: 6)
                    }
                }
                .padding(.horizontal)

                // Teams — sorted by record, then dongs
                LazyVStack(spacing: 12) {
                    ForEach(Array(sortedTeams.enumerated()), id: \.element.id) { index, team in
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
                    AztecSectionHeader(title: "\(unassigned.count) Free Agents", color: AztecTheme.hotPink)
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

    /// Compute team record (wins-losses) from tournament games
    private var teamRecord: String {
        guard let tournament = cloudService.tournament else { return "0-0" }
        var wins = 0
        var losses = 0
        for tier in tournament.tiers {
            for game in tier.games where game.status == .completed {
                guard let winnerId = game.winnerId else { continue }
                if game.team1Id == team.id || game.team2Id == team.id {
                    if winnerId == team.id { wins += 1 } else { losses += 1 }
                }
            }
        }
        return "\(wins)-\(losses)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TeamIconView(team: team, size: 48)

                // Team name — 2x large
                Text(team.name)
                    .font(AztecTheme.hobbsFont(size: 56))
                    .tracking(AztecTheme.hobbsKerning)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundColor(AztecTheme.neonYellow)
                    .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 3)

                Spacer()

                // Team record (replaces dongs)
                VStack(spacing: 2) {
                    Text(teamRecord)
                        .font(AztecTheme.sfProBold(size: 22))
                        .foregroundColor(AztecTheme.neonYellow)
                        .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 3)

                    Text("RECORD")
                        .font(AztecTheme.sfProBold(size: 10))
                        .foregroundColor(AztecTheme.hotPink)
                }
            }

            // Player names — SF Pro, pink
            if !teamPlayers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(teamPlayers) { player in
                            Text(player.name)
                                .font(AztecTheme.sfProBold(size: 16))
                                .foregroundColor(AztecTheme.hotPink)
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
                .font(AztecTheme.hobbsFont(size: 26))
                .tracking(AztecTheme.hobbsKerning)
                .foregroundColor(AztecTheme.neonYellow)

            Spacer()

            Button("ASSIGN") {
                showTeamPicker = true
            }
            .buttonStyle(AztecSecondaryButtonStyle(color: AztecTheme.hotPink))
        }
        .padding(12)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AztecTheme.hotPink.opacity(0.5), lineWidth: 2.25)
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
                                        .tracking(AztecTheme.hobbsKerning)
                                        .foregroundColor(AztecTheme.neonYellow)

                                    Spacer()
                                }
                                .padding(14)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AztecTheme.hotPink.opacity(0.4), lineWidth: 2.25)
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
                        .dismissButtonStyle()
                }
            }
        }
    }
}

struct AddTeamSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    @State private var teamName = ""
    @State private var iconName = ""
    @State private var playerNames: [String] = [""]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        AztecSectionHeader(title: "Create Squad")

                        TextField("Squad Name", text: $teamName)
                            .aztecTextField()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("TEAM ICON")
                                .font(AztecTheme.sfProBold(size: 12))
                                .foregroundColor(AztecTheme.hotPink)
                            TextField("Asset name (e.g. team-rosecity)", text: $iconName)
                                .aztecTextField()
                        }

                        // Player names section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("BALLERS")
                                .font(AztecTheme.sfProBold(size: 12))
                                .foregroundColor(AztecTheme.hotPink)

                            ForEach(playerNames.indices, id: \.self) { index in
                                HStack(spacing: 8) {
                                    TextField("Baller Name", text: $playerNames[index])
                                        .aztecTextField()

                                    if playerNames.count > 1 {
                                        Button {
                                            playerNames.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(AztecTheme.bloodRed.opacity(0.6))
                                                .font(.system(size: 20))
                                        }
                                    }
                                }
                            }

                            Button {
                                playerNames.append("")
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("ADD BALLER")
                                }
                                .font(AztecTheme.sfProBold(size: 14))
                                .foregroundColor(AztecTheme.neonYellow)
                            }
                        }

                        Button("CREATE SQUAD") {
                            guard !teamName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            Task {
                                let trimmedName = teamName.trimmingCharacters(in: .whitespaces)
                                let trimmedIcon = iconName.trimmingCharacters(in: .whitespaces)
                                await cloudService.addTeam(name: trimmedName)
                                // Set icon if provided
                                if !trimmedIcon.isEmpty,
                                   let team = cloudService.teams.first(where: { $0.name == trimmedName }) {
                                    var updated = team
                                    updated.iconName = trimmedIcon
                                    await cloudService.updateTeam(updated)
                                }
                                // Add players to the new team
                                if let team = cloudService.teams.first(where: { $0.name == trimmedName }) {
                                    for name in playerNames {
                                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                                        if !trimmed.isEmpty {
                                            await cloudService.addPlayer(name: trimmed, teamId: team.id)
                                        }
                                    }
                                }
                                dismiss()
                            }
                        }
                        .buttonStyle(AztecButtonStyle())
                        .disabled(teamName.trimmingCharacters(in: .whitespaces).isEmpty)

                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("New Squad")
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

struct TeamDetailSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    let team: Team
    @State private var showDeleteConfirm = false
    @State private var showAddPlayerPicker = false
    @State private var showBadgePicker = false

    var teamPlayers: [Player] {
        cloudService.playersForTeam(team.id)
    }

    private var teamRecord: String {
        guard let tournament = cloudService.tournament else { return "0-0" }
        var wins = 0, losses = 0
        for tier in tournament.tiers {
            for game in tier.games where game.status == .completed {
                guard let winnerId = game.winnerId else { continue }
                if game.team1Id == team.id || game.team2Id == team.id {
                    if winnerId == team.id { wins += 1 } else { losses += 1 }
                }
            }
        }
        return "\(wins)-\(losses)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Team badge — tap to change
                        Button {
                            showBadgePicker = true
                        } label: {
                            VStack(spacing: 4) {
                                TeamIconView(team: team, size: 90)
                                    .shadow(color: AztecTheme.hotPink.opacity(0.3), radius: 12)
                                Text("TAP TO CHANGE BADGE")
                                    .font(AztecTheme.sfProBold(size: 9))
                                    .tracking(1)
                                    .foregroundColor(AztecTheme.dimText)
                            }
                        }

                        // Team name
                        Text(team.name)
                            .font(AztecTheme.hobbsFont(size: 44))
                            .tracking(AztecTheme.hobbsKerning)
                            .foregroundColor(AztecTheme.neonYellow)
                            .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 4)

                        // Team record below icon
                        VStack(spacing: 2) {
                            Text(teamRecord)
                                .font(AztecTheme.hobbsFont(size: 36))
                                .tracking(AztecTheme.hobbsKerning)
                                .foregroundColor(AztecTheme.neonYellow)
                                .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 3)
                            Text("RECORD")
                                .font(AztecTheme.sfProBold(size: 12))
                                .foregroundColor(AztecTheme.hotPink)
                        }

                        // Squad stats summary — all yellow numbers, pink labels
                        let totalDongs = teamPlayers.reduce(0) { $0 + $1.stats.dongs }
                        let totalSalamies = teamPlayers.reduce(0) { $0 + $1.stats.salamies }
                        let totalDP = teamPlayers.reduce(0) { $0 + $1.stats.doublePlays }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            StatBubble(value: totalDongs, label: "DONGS", color: AztecTheme.neonYellow)
                            StatBubble(value: totalSalamies, label: "SALAMIES", color: AztecTheme.neonYellow)
                            StatBubble(value: totalDP, label: "DBL PLAYS", color: AztecTheme.neonYellow)
                        }
                        .padding(16)
                        .neonCard()

                        // Roster — 20% larger, pink with gold glow
                        HStack {
                            Text("ROSTER")
                                .font(AztecTheme.hobbsFont(size: 44))
                                .tracking(AztecTheme.hobbsKerning)
                                .foregroundColor(AztecTheme.hotPink)
                                .shadow(color: AztecTheme.neonYellow.opacity(0.4), radius: 4)
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
                            VStack(spacing: 0) {
                                HStack {
                                    Text(player.name)
                                        .font(AztecTheme.hobbsFont(size: 30))
                                        .tracking(AztecTheme.hobbsKerning)
                                        .foregroundColor(AztecTheme.neonYellow)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)

                                    Spacer()

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
                                .padding(.horizontal, 12)
                                .padding(.top, 10)
                                .padding(.bottom, 6)

                                // Full stats for each player
                                VStack(spacing: 4) {
                                    PlayerStatRow(label: "Dongs", value: player.stats.dongs)
                                    PlayerStatRow(label: "Salamies", value: player.stats.salamies)
                                    PlayerStatRow(label: "Dbl Plays", value: player.stats.doublePlays)
                                    PlayerStatRow(label: "Drops", value: player.stats.drops)
                                }
                                .padding(.horizontal, 12)
                                .padding(.bottom, 10)
                            }
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AztecTheme.hotPink.opacity(0.3), lineWidth: 2.25)
                            )
                        }

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
                        .dismissButtonStyle()
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
            .sheet(isPresented: $showBadgePicker) {
                BadgePickerSheet(team: team)
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
                                .foregroundColor(AztecTheme.hotPink)
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
                                        .font(AztecTheme.sfProBold(size: 18))
                                        .foregroundColor(AztecTheme.neonYellow)

                                    Spacer()

                                    if player.teamId == team.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AztecTheme.neonYellow)
                                    } else if let currentTeamId = player.teamId,
                                       let currentTeam = cloudService.team(for: currentTeamId) {
                                        Text(currentTeam.name)
                                            .font(AztecTheme.sfProMedium(size: 12))
                                            .foregroundColor(AztecTheme.hotPink)
                                    } else {
                                        Text("Free Agent")
                                            .font(AztecTheme.sfProMedium(size: 12))
                                            .foregroundColor(AztecTheme.hotPink)
                                    }
                                }
                                .padding(14)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AztecTheme.hotPink.opacity(0.3), lineWidth: 2.25)
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
                        .dismissButtonStyle()
                }
            }
        }
    }
}

struct BadgePickerSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    let team: Team

    // Badge asset names matching team identities
    static let availableBadges = [
        "badge-banditos", "badge-no-mames-jovenes",
        "badge-mothership-jv-reds", "badge-mothership-jv-blacks",
        "badge-tinseltown-jv", "badge-rose-city-jv",
        "badge-dss", "badge-steel-city", "badge-gold-coast",
        "badge-mothership-champs", "badge-tinseltown-champs",
        "badge-rose-city-champs", "badge-jet-city-champs",
        "badge-no-mames-viejos"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        AztecSectionHeader(title: "Choose Badge")

                        Text("Select a badge for \(team.name)")
                            .font(AztecTheme.sfProMedium(size: 14))
                            .foregroundColor(AztecTheme.hotPink)

                        // Clear badge option
                        Button {
                            Task {
                                var updated = team
                                updated.iconName = nil
                                await cloudService.updateTeam(updated)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Text("NO BADGE")
                                    .font(AztecTheme.sfProBold(size: 14))
                                    .foregroundColor(AztecTheme.dimText)
                                Spacer()
                                if team.iconName == nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AztecTheme.neonYellow)
                                }
                            }
                            .padding(14)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AztecTheme.hotPink.opacity(0.3), lineWidth: 2.25)
                            )
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 12)], spacing: 12) {
                            ForEach(Self.availableBadges, id: \.self) { badge in
                                Button {
                                    Task {
                                        var updated = team
                                        updated.iconName = badge
                                        await cloudService.updateTeam(updated)
                                        dismiss()
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(badge)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 64, height: 64)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        if team.iconName == badge {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(AztecTheme.neonYellow)
                                        }
                                    }
                                    .padding(8)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                team.iconName == badge
                                                    ? AztecTheme.neonYellow
                                                    : AztecTheme.hotPink.opacity(0.3),
                                                lineWidth: team.iconName == badge ? 2.25 : 1.5
                                            )
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Team Badge")
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

struct PlayerStatRow: View {
    let label: String
    let value: Int

    var body: some View {
        HStack {
            Text(label)
                .font(AztecTheme.hobbsFont(size: 20))
                .tracking(AztecTheme.hobbsKerning)
                .foregroundColor(AztecTheme.hotPink)

            Spacer()

            Text("\(value)")
                .font(AztecTheme.sfProBold(size: 18))
                .foregroundColor(AztecTheme.neonYellow)
                .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 2)
        }
        .padding(.horizontal, 4)
    }
}

struct StatBubble: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(AztecTheme.hobbsFont(size: 24))
                .tracking(AztecTheme.hobbsKerning)
                .foregroundColor(AztecTheme.neonYellow)
                .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 3)
            Text(label)
                .font(AztecTheme.sfProBold(size: 10))
                .foregroundColor(AztecTheme.hotPink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}
