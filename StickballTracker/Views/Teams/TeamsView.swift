import SwiftUI

struct TeamsView: View {
    @EnvironmentObject var cloudService: CloudSyncService
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

            // Player names — SF Pro, pink, wrapping up to 2 lines
            if !teamPlayers.isEmpty {
                Text(teamPlayers.map { $0.name }.joined(separator: "  ·  "))
                    .font(AztecTheme.sfProBold(size: 16))
                    .foregroundColor(AztecTheme.hotPink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .neonCard()
        .overlay {
            if cloudService.isTeamEliminated(team.id) {
                GeometryReader { geo in
                    Text("LOSER")
                        .font(AztecTheme.hobbsFont(size: geo.size.height * 0.7))
                        .tracking(AztecTheme.hobbsKerning)
                        .foregroundColor(AztecTheme.tennisGreen)
                        .shadow(color: AztecTheme.tennisGreen.opacity(0.6), radius: 6)
                        .rotationEffect(.degrees(-30))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .allowsHitTesting(false)
                }
                .allowsHitTesting(false)
            }
        }
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

            if cloudService.accessLevel == .admin {
                Button("ASSIGN") {
                    showTeamPicker = true
                }
                .buttonStyle(AztecSecondaryButtonStyle(color: AztecTheme.hotPink))
            }
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

                        ForEach(cloudService.allowedTeamsForPlayer(player)) { team in
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
    @State private var showCreatePlayer = false

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
                        // Team badge
                        TeamIconView(team: team, size: 90)

                        // Team name
                        Text(team.name)
                            .font(AztecTheme.hobbsFont(size: 44))
                            .tracking(AztecTheme.hobbsKerning)
                            .foregroundColor(AztecTheme.neonYellow)
                            .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 4)

                        // Team record below icon
                        VStack(spacing: 2) {
                            Text(teamRecord)
                                .font(AztecTheme.hobbsFont(size: 54))
                                .tracking(AztecTheme.hobbsKerning)
                                .foregroundColor(AztecTheme.neonYellow)
                                .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 3)
                            Text("RECORD")
                                .font(AztecTheme.sfProBold(size: 18))
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
                            if cloudService.accessLevel == .admin {
                                Button {
                                    showAddPlayerPicker = true
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(AztecTheme.neonYellow)
                                        .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 3)
                                }
                            }
                        }

                        if cloudService.accessLevel == .admin {
                            Button {
                                showCreatePlayer = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.badge.plus")
                                    Text("CREATE NEW BALLER")
                                }
                                .font(AztecTheme.sfProBold(size: 14))
                                .foregroundColor(AztecTheme.neonYellow)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AztecTheme.neonYellow.opacity(0.5), lineWidth: 2.25)
                                )
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

                                    if cloudService.accessLevel == .admin {
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

                        if cloudService.accessLevel == .admin {
                            Button("DELETE SQUAD") {
                                showDeleteConfirm = true
                            }
                            .buttonStyle(AztecSecondaryButtonStyle(color: AztecTheme.bloodRed))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("")
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
            .sheet(isPresented: $showCreatePlayer) {
                CreatePlayerSheet(team: team)
            }
        }
    }
}

struct CreatePlayerSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    let team: Team
    @State private var playerName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    AztecSectionHeader(title: "New Baller")

                    Text("Adding to \(team.name)")
                        .font(AztecTheme.sfProMedium(size: 14))
                        .foregroundColor(AztecTheme.hotPink)

                    TextField("Baller Name", text: $playerName)
                        .aztecTextField()

                    Button("CREATE BALLER") {
                        let trimmed = playerName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        Task {
                            await cloudService.addPlayer(name: trimmed, teamId: team.id)
                            dismiss()
                        }
                    }
                    .buttonStyle(AztecButtonStyle())
                    .disabled(playerName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Create Baller")
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

struct AddPlayerToTeamSheet: View {
    @EnvironmentObject var cloudService: CloudSyncService
    @Environment(\.dismiss) var dismiss
    let team: Team

    var availablePlayers: [Player] {
        cloudService.players.filter { player in
            // Exclude players already on this team
            guard player.teamId != team.id else { return false }
            // Enforce draft pool restrictions: only show players
            // whose allowed teams include the target team
            let allowed = cloudService.allowedTeamsForPlayer(player)
            return allowed.contains(where: { $0.id == team.id })
        }
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

struct PlayerStatRow: View {
    let label: String
    let value: Int

    var body: some View {
        HStack {
            Text(label)
                .font(AztecTheme.hobbsFont(size: 30))
                .tracking(AztecTheme.hobbsKerning)
                .foregroundColor(AztecTheme.hotPink)

            Spacer()

            Text("\(value)")
                .font(AztecTheme.sfProBold(size: 27))
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
                .font(AztecTheme.hobbsFont(size: 36))
                .tracking(AztecTheme.hobbsKerning)
                .foregroundColor(AztecTheme.neonYellow)
                .shadow(color: AztecTheme.neonYellow.opacity(0.3), radius: 3)
            Text(label)
                .font(AztecTheme.sfProBold(size: 15))
                .foregroundColor(AztecTheme.hotPink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}
