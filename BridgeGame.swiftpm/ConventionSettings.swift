// BRIDGE APP — Built 2026-06-07
import Foundation

// MARK: - Variant enums (Codable via String raw value)

enum StaymanVariant: String, CaseIterable, Codable {
    case standard = "Standard (Non-Forcing)"
    case forcing  = "Forcing"
    case puppet   = "Puppet (over 2NT)"
}

enum OvercallStyle: String, CaseIterable, Codable {
    case light = "Light (8+ HCP)"
    case sound = "Sound (10+ HCP)"
}

// MARK: - Settings model

struct ConventionSettings: Codable {
    // ── Stayman ──────────────────────────────────────────────────────────────
    var staymanEnabled: Bool = true
    var staymanVariant: StaymanVariant = .standard

    // ── Jacoby Transfers ─────────────────────────────────────────────────────
    var jacobyTransfersEnabled: Bool = true
    var transfersOverInterference: Bool = false
    var superAcceptThreshold: Int = 17     // 17 or 18

    // ── New Minor Forcing ────────────────────────────────────────────────────
    var nmfEnabled: Bool = true
    var nmfInclude2C: Bool = true          // whether 2♣ rebid by opener triggers NMF

    // ── XYZ (Two-Way New Minor) ───────────────────────────────────────────────
    var xyzEnabled: Bool = false

    // ── Jacoby 2NT ───────────────────────────────────────────────────────────
    var jacoby2NTEnabled: Bool = true

    // ── Splinters ────────────────────────────────────────────────────────────
    var splinterEnabled: Bool = true
    var splinterMinHCP: Int = 13           // configurable 13–16

    // ── Takeout Doubles ──────────────────────────────────────────────────────
    var takeoutDoubleEnabled: Bool = true
    var takeoutDoubleMinHCP: Int = 12      // configurable 12–14

    // ── Overcalls ────────────────────────────────────────────────────────────
    var overcallEnabled: Bool = true
    var overcallStyle: OvercallStyle = .sound
    var overcall2LevelMinHCP: Int = 10     // configurable; sound = 10, light = 8

    // ── UI ───────────────────────────────────────────────────────────────────
    var useAlternateColors: Bool = false   // clubs → blue, diamonds → orange

    // ── Persistence ──────────────────────────────────────────────────────────
    static let defaults = ConventionSettings()

    static func load() -> ConventionSettings {
        guard let data = UserDefaults.standard.data(forKey: "bridgeConventionSettings"),
              let decoded = try? JSONDecoder().decode(ConventionSettings.self, from: data)
        else { return ConventionSettings() }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: "bridgeConventionSettings")
    }
}
