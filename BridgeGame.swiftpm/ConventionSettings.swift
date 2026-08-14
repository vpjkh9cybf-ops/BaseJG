// BRIDGE APP — Built 2026-06-07
import Foundation

// MARK: - Variation enums (Codable via String raw value)

enum StaymanVariant: String, CaseIterable, Codable {
    case standard = "Standard (Non-Forcing)"
    case forcing  = "Forcing Stayman"
    case puppet   = "Puppet Stayman"
    case garbage  = "Garbage / Crawling"

    var detail: String {
        switch self {
        case .standard: return "2♣ asks for a 4-card major. Responder may pass opener's rebid."
        case .forcing:  return "2♣ creates a game force — the auction cannot die below game."
        case .puppet:   return "2♣ (or 3♣ over 2NT) asks for a 5-card major first, then 4-card majors."
        case .garbage:  return "2♣ on a weak hand short in clubs, planning to pass any major reply."
        }
    }
}

enum SmolenSetting: String, CaseIterable, Codable {
    case on  = "On"
    case off = "Off"

    var detail: String {
        switch self {
        case .on:  return "After 1NT–2♣–2♦, jump in your 4-card major to show 5-4 majors, game force."
        case .off: return "After 1NT–2♣–2♦, bid your 5-card major naturally."
        }
    }
}

enum TransferStyle: String, CaseIterable, Codable {
    case majorsOnly = "Majors Only (2♦ / 2♥)"
    case fourSuit   = "Four-Suit (adds 2♠ / 2NT)"

    var detail: String {
        switch self {
        case .majorsOnly: return "2♦ → hearts, 2♥ → spades. 2♠ is a natural or invitational bid."
        case .fourSuit:   return "Also 2♠ → clubs and 2NT → diamonds, so every suit can be transferred."
        }
    }
}

enum TexasSetting: String, CaseIterable, Codable {
    case on  = "On"
    case off = "Off"

    var detail: String {
        switch self {
        case .on:  return "4♦ → 4♥ and 4♥ → 4♠ show 6+ cards and game values with no slam interest."
        case .off: return "Jump straight to game in your long major."
        }
    }
}

enum WeakTwoStyle: String, CaseIterable, Codable {
    case disciplined = "Disciplined (6–10, good suit)"
    case modern      = "Modern (5–11, any suit)"
    case aggressive  = "Aggressive (4–11, wide range)"

    var hcpRange: ClosedRange<Int> {
        switch self {
        case .disciplined: return 6...10
        case .modern:      return 5...11
        case .aggressive:  return 4...11
        }
    }

    var detail: String {
        switch self {
        case .disciplined: return "Two of the top three honours required. Partner can trust the suit."
        case .modern:      return "Any decent 6-card suit. Vulnerability still tightens the standard."
        case .aggressive:  return "Preempt on shape and position. Partner must allow for a wide range."
        }
    }
}

enum WeakTwoResponse: String, CaseIterable, Codable {
    case ogust   = "Ogust (2NT asks suit + hand)"
    case feature = "Feature (2NT asks for an A/K)"
    case mcCabe  = "McCabe (3♣ relay to sign off)"

    var detail: String {
        switch self {
        case .ogust:   return "3♣ bad/bad, 3♦ bad suit good hand, 3♥ good suit bad hand, 3♠ good/good, 3NT solid."
        case .feature: return "Opener names an outside ace or king with a maximum, else rebids the suit."
        case .mcCabe:  return "After an overcall, 3♣ asks opener to bid 3♦ so responder can pick a spot."
        }
    }
}

enum OneNTResponseStyle: String, CaseIterable, Codable {
    case forcing     = "Forcing 1NT"
    case semiForcing = "Semi-Forcing 1NT"

    var detail: String {
        switch self {
        case .forcing:     return "Opener must bid again over 1NT, even with a flat minimum."
        case .semiForcing: return "Opener may pass 1NT with a balanced minimum and no fit."
        }
    }
}

enum TwoOverOneScope: String, CaseIterable, Codable {
    case gameForcing      = "Game Forcing"
    case gameForcingUnpassed = "GF Only by Unpassed Hand"

    var detail: String {
        switch self {
        case .gameForcing:         return "A 2/1 response always forces to game."
        case .gameForcingUnpassed: return "By a passed hand, 2/1 is invitational instead of forcing."
        }
    }
}

enum NegativeDoubleLevel: String, CaseIterable, Codable {
    case through2S = "Through 2♠"
    case through3S = "Through 3♠"
    case through4H = "Through 4♥"
    case unlimited = "Any Level"

    var detail: String {
        switch self {
        case .through2S: return "Above 2♠ a double is penalty — the classic, most common agreement."
        case .through3S: return "Keeps the double takeout-flavoured one level higher."
        case .through4H: return "Very wide-ranging; doubles stay takeout up to 4♥."
        case .unlimited: return "Doubles of an overcall are never penalty."
        }
    }
}

enum MichaelsStyle: String, CaseIterable, Codable {
    case weakOrStrong = "Weak or Strong (two-way)"
    case weakOnly     = "Weak Only"
    case strongOnly   = "Strong Only"

    var detail: String {
        switch self {
        case .weakOrStrong: return "Either 6–11 or 16+ HCP. Partner asks with a relay when interested."
        case .weakOnly:     return "Always a preemptive 5-5. Strong two-suiters start with a double."
        case .strongOnly:   return "Shows opening values or better with 5-5."
        }
    }
}

enum DruryStyle: String, CaseIterable, Codable {
    case standard = "Standard Drury"
    case reverse  = "Reverse Drury"
    case twoWay   = "Two-Way Drury"

    var detail: String {
        switch self {
        case .standard: return "2♣ by a passed hand shows 3+ support and 10–12. Opener rebids 2♦ if minimum."
        case .reverse:  return "Opener rebids their major to show a minimum; anything else is a game try."
        case .twoWay:   return "2♣ shows 3-card support, 2♦ shows 4+ support. Both promise 10–12."
        }
    }
}

enum NTDefense: String, CaseIterable, Codable {
    case cappelletti = "Cappelletti / Hamilton"
    case dont        = "DONT"
    case landy       = "Landy"
    case meckwell    = "Meckwell"
    case natural     = "Natural"

    var detail: String {
        switch self {
        case .cappelletti: return "2♣ any one-suiter, 2♦ both majors, 2♥/2♠ that major + a minor, 2NT both minors."
        case .dont:        return "Double any one-suiter, 2♣ clubs + higher, 2♦ diamonds + higher, 2♥ hearts + spades."
        case .landy:       return "2♣ shows both majors; everything else is natural."
        case .meckwell:    return "Double a minor or both majors, 2♣/2♦ that minor + a major, 2♥/2♠ natural."
        case .natural:     return "All overcalls are natural; double is penalty."
        }
    }
}

enum LebensohlSetting: String, CaseIterable, Codable {
    case off        = "Off"
    case afterNT    = "After Interference over 1NT"
    case afterDbl   = "Also after Weak-Two Doubles"

    var detail: String {
        switch self {
        case .off:      return "Direct bids only; no relay available to distinguish weak from invitational."
        case .afterNT:  return "2NT relays to 3♣, letting responder separate sign-offs from real values."
        case .afterDbl: return "Same 2NT relay is also used after partner doubles a weak two."
        }
    }
}

enum CueBidStyle: String, CaseIterable, Codable {
    case italian = "Italian (any control)"
    case standard = "Standard (first-round only)"

    var detail: String {
        switch self {
        case .italian:  return "Cue bid aces, kings, singletons and voids up the line."
        case .standard: return "Cue bid aces and voids first; kings and singletons only on the second round."
        }
    }
}

enum FourthSuitStyle: String, CaseIterable, Codable {
    case gameForcing     = "Game Forcing"
    case oneRoundForcing = "One Round Forcing"

    var detail: String {
        switch self {
        case .gameForcing:     return "Fourth suit sets up a game force — the most common modern treatment."
        case .oneRoundForcing: return "Fourth suit is forcing for one round only; responder may stop below game."
        }
    }
}

enum MinorRaiseStyle: String, CaseIterable, Codable {
    case standard = "Standard Raises"
    case inverted = "Inverted Minors"

    var detail: String {
        switch self {
        case .standard: return "A single raise is weak, a jump raise is invitational."
        case .inverted: return "A single raise is 10+ and forcing; a jump raise is preemptive."
        }
    }
}

enum SlamAskStyle: String, CaseIterable, Codable {
    case rkcb1430 = "RKCB 1430"
    case rkcb0314 = "RKCB 0314"
    case standardBW = "Standard Blackwood"

    var detail: String {
        switch self {
        case .rkcb1430:   return "5♣ = 1 or 4 key cards, 5♦ = 0 or 3. The trump king is a fifth key card."
        case .rkcb0314:   return "5♣ = 0 or 3 key cards, 5♦ = 1 or 4. Otherwise identical to 1430."
        case .standardBW: return "4NT asks for aces only: 5♣ = 0 or 4, 5♦ = 1, 5♥ = 2, 5♠ = 3."
        }
    }
}

enum OvercallStyle: String, CaseIterable, Codable {
    case light = "Light (8+ HCP)"
    case sound = "Sound (10+ HCP)"

    var detail: String {
        switch self {
        case .light: return "Overcall freely on shape to compete and suggest a lead."
        case .sound: return "Overcall only with real values so partner can raise with confidence."
        }
    }
}

// MARK: - Settings model

struct ConventionSettings: Codable {
    // ── Stayman ──────────────────────────────────────────────────────────────
    var staymanEnabled: Bool = true
    var staymanVariant: StaymanVariant = .standard
    var smolen: SmolenSetting = .off

    // ── Jacoby Transfers ─────────────────────────────────────────────────────
    var jacobyTransfersEnabled: Bool = true
    var transferStyle: TransferStyle = .majorsOnly
    var texasTransfers: TexasSetting = .off
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
    var miniSplinters: Bool = false

    // ── Weak Twos ────────────────────────────────────────────────────────────
    var weakTwoEnabled: Bool = true
    var weakTwoStyle: WeakTwoStyle = .disciplined
    var weakTwoResponse: WeakTwoResponse = .ogust

    // ── 2/1 Game Force ───────────────────────────────────────────────────────
    var twoOverOneEnabled: Bool = true
    var twoOverOneScope: TwoOverOneScope = .gameForcing
    var oneNTResponseStyle: OneNTResponseStyle = .forcing

    // ── Takeout & Negative Doubles ───────────────────────────────────────────
    var takeoutDoubleEnabled: Bool = true
    var takeoutDoubleMinHCP: Int = 12      // configurable 12–14
    var negativeDoubleEnabled: Bool = true
    var negativeDoubleLevel: NegativeDoubleLevel = .through2S
    var supportDoubles: Bool = false

    // ── Overcalls & Two-Suiters ──────────────────────────────────────────────
    var overcallEnabled: Bool = true
    var overcallStyle: OvercallStyle = .sound
    var overcall2LevelMinHCP: Int = 10     // configurable; sound = 10, light = 8
    var michaelsEnabled: Bool = true
    var michaelsStyle: MichaelsStyle = .weakOrStrong
    var unusual2NTEnabled: Bool = true

    // ── Competitive Gadgets ──────────────────────────────────────────────────
    var druryEnabled: Bool = false
    var druryStyle: DruryStyle = .standard
    var ntDefense: NTDefense = .cappelletti
    var lebensohl: LebensohlSetting = .off

    // ── Constructive Gadgets ─────────────────────────────────────────────────
    var fourthSuitStyle: FourthSuitStyle = .gameForcing
    var minorRaiseStyle: MinorRaiseStyle = .standard
    var cueBidStyle: CueBidStyle = .italian

    // ── Slam Bidding ─────────────────────────────────────────────────────────
    var slamAskStyle: SlamAskStyle = .rkcb1430
    var gerberEnabled: Bool = true
    var exclusionRKCB: Bool = false
    var kickbackEnabled: Bool = false

    // ── UI ───────────────────────────────────────────────────────────────────
    var useAlternateColors: Bool = false   // clubs → blue, diamonds → orange

    // ── Persistence ──────────────────────────────────────────────────────────
    // Key is versioned: adding fields invalidates older payloads rather than
    // failing to decode and silently losing every setting at once.
    private static let storageKey = "bridgeConventionSettings.v2"

    static let defaults = ConventionSettings()

    static func load() -> ConventionSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(ConventionSettings.self, from: data)
        else { return ConventionSettings() }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: ConventionSettings.storageKey)
    }
}
