import Foundation

enum BracketNames {
    static let map: [String: String] = [
        "Tinseltown Champs": "TTFB Champs",
        "Tinseltown JV": "TTFB JV",
        "Rose City Champs": "Rose Champs",
        "Rose City JV": "Rose JV",
        "Mothership Champs": "Mother Champs",
        "Mothership JV Blacks": "Mother Black JV",
        "Mothership JV Reds": "Mother Red JV",
        "No Mames Wey Jovenes": "Jovenes",
        "No Mames Wey Viejos": "Viejos",
        "Jet City Champs": "Jets",
        "Steel City": "Steel",
        "Banditos": "Bandits",
        "Gold Coast": "Coast",
        "D$$": "D$$",
    ]

    static func displayName(for team: Team) -> String {
        map[team.name] ?? String(team.name.prefix(8))
    }

    static func splitTeamName(_ name: String) -> [String] {
        if name.hasPrefix("Mothership JV") {
            return ["Mothership", String(name.dropFirst("Mothership ".count))]
        }
        if name.hasPrefix("No Mames Wey") && name.count > "No Mames Wey".count {
            return ["No Mames Wey", String(name.dropFirst("No Mames Wey ".count))]
        }
        return [name]
    }
}
