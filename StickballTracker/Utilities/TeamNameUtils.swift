import Foundation

/// Splits long team names onto two lines for display in schedule cards,
/// game entry sheets, and other compact views.
///
///   "Mothership JV Reds"   → ["Mothership", "JV Reds"]
///   "Mothership JV Blacks" → ["Mothership", "JV Blacks"]
///   "No Mames Wey Jovenes" → ["No Mames Wey", "Jovenes"]
///   "No Mames Wey Viejos"  → ["No Mames Wey", "Viejos"]
///   "Banditos"             → ["Banditos"]
func splitTeamName(_ name: String) -> [String] {
    if name.hasPrefix("Mothership JV") {
        return ["Mothership", String(name.dropFirst("Mothership ".count))]
    }
    if name.hasPrefix("No Mames Wey") && name.count > "No Mames Wey".count {
        return ["No Mames Wey", String(name.dropFirst("No Mames Wey ".count))]
    }
    return [name]
}
