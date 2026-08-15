// Conventional Wisdom — modified 2026-08-14 13:00 UTC
import SwiftUI

// Small caption used under every picker to explain the chosen variation.
struct SettingDetail: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                // Form's ViewBuilder caps out at 10 children, so the sections are
                // bundled into Groups.
                Group {
                    gameSection
                    slamSection
                    staymanSection
                    transferSection
                    minorForcingSection
                }
                Group {
                    majorRaiseSection
                    weakTwoSection
                    twoOverOneSection
                    doubleSection
                    overcallSection
                }
                Group {
                    competitiveSection
                    constructiveSection
                    displaySection
                    resetSection
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Game

    private var gameSection: some View {
        Section("Game") {
            Toggle("Play declarer's hand when I would be dummy",
                   isOn: $game.switchSeatsForDeclarer)
            SettingDetail(text: game.switchSeatsForDeclarer
                          ? "When North wins the auction you play North's cards and South becomes the visible dummy."
                          : "When North wins the auction the AI declares and you watch, playing only South's dummy cards.")

            Picker("Scoring Mode", selection: $game.scoringMode) {
                ForEach(ScoringMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            SettingDetail(text: game.scoringMode == .chicago
                          ? "Chicago: 4 deals, fixed vulnerability, game bonus paid each hand."
                          : "Rubber: first side to two games wins; points accumulate above and below the line.")
        }
    }

    // MARK: - Slam bidding

    private var slamSection: some View {
        Section("Slam Bidding") {
            Picker("Ace Ask", selection: $game.conventionSettings.slamAskStyle) {
                ForEach(SlamAskStyle.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.menu)
            SettingDetail(text: game.conventionSettings.slamAskStyle.detail)

            Toggle("Gerber (4♣ over notrump)", isOn: $game.conventionSettings.gerberEnabled)
            Toggle("Exclusion RKCB (Voidwood)", isOn: $game.conventionSettings.exclusionRKCB)
            Toggle("Kickback (suit-based 4NT)", isOn: $game.conventionSettings.kickbackEnabled)

            Picker("Control Cue Bids", selection: $game.conventionSettings.cueBidStyle) {
                ForEach(CueBidStyle.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.menu)
            SettingDetail(text: game.conventionSettings.cueBidStyle.detail)
        }
    }

    // MARK: - Stayman

    private var staymanSection: some View {
        Section("Stayman") {
            Toggle("Enable Stayman", isOn: $game.conventionSettings.staymanEnabled)
            if game.conventionSettings.staymanEnabled {
                Picker("Variation", selection: $game.conventionSettings.staymanVariant) {
                    ForEach(StaymanVariant.allCases, id: \.self) { v in
                        Text(v.rawValue).tag(v)
                    }
                }
                .pickerStyle(.menu)
                SettingDetail(text: game.conventionSettings.staymanVariant.detail)

                Picker("Smolen", selection: $game.conventionSettings.smolen) {
                    ForEach(SmolenSetting.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                SettingDetail(text: game.conventionSettings.smolen.detail)
            }
        }
    }

    // MARK: - Jacoby Transfers

    private var transferSection: some View {
        Section("Jacoby Transfers") {
            Toggle("Enable Jacoby Transfers", isOn: $game.conventionSettings.jacobyTransfersEnabled)
            if game.conventionSettings.jacobyTransfersEnabled {
                Picker("Range", selection: $game.conventionSettings.transferStyle) {
                    ForEach(TransferStyle.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu)
                SettingDetail(text: game.conventionSettings.transferStyle.detail)

                Picker("Texas Transfers", selection: $game.conventionSettings.texasTransfers) {
                    ForEach(TexasSetting.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                SettingDetail(text: game.conventionSettings.texasTransfers.detail)

                Toggle("Active over interference", isOn: $game.conventionSettings.transfersOverInterference)
                Stepper("Super-accept: \(game.conventionSettings.superAcceptThreshold)+ HCP",
                        value: $game.conventionSettings.superAcceptThreshold, in: 17...18)
            }
        }
    }

    // MARK: - New Minor Forcing / XYZ

    private var minorForcingSection: some View {
        Section("Checkback after 1NT Rebid") {
            Toggle("New Minor Forcing", isOn: $game.conventionSettings.nmfEnabled)
            if game.conventionSettings.nmfEnabled {
                Toggle("2♣ rebid triggers NMF", isOn: $game.conventionSettings.nmfInclude2C)
            }
            Toggle("XYZ (Two-Way New Minor)", isOn: $game.conventionSettings.xyzEnabled)
            SettingDetail(text: "XYZ: after two one-level bids, 2♣ relays to 2♦ (weak or invitational) and 2♦ is game forcing.")

            Picker("Fourth Suit Forcing", selection: $game.conventionSettings.fourthSuitStyle) {
                ForEach(FourthSuitStyle.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.menu)
            SettingDetail(text: game.conventionSettings.fourthSuitStyle.detail)
        }
    }

    // MARK: - Major raises

    private var majorRaiseSection: some View {
        Section("Major Suit Raises") {
            Toggle("Jacoby 2NT", isOn: $game.conventionSettings.jacoby2NTEnabled)
            SettingDetail(text: "2NT over partner's 1♥/1♠ shows 4+ trumps and game-forcing values, asking opener to describe shape.")

            Toggle("Splinters", isOn: $game.conventionSettings.splinterEnabled)
            if game.conventionSettings.splinterEnabled {
                Stepper("Splinter min HCP: \(game.conventionSettings.splinterMinHCP)",
                        value: $game.conventionSettings.splinterMinHCP, in: 13...16)
                Toggle("Mini-splinters", isOn: $game.conventionSettings.miniSplinters)
                SettingDetail(text: "Mini-splinters show the same shortness with invitational rather than game-forcing values.")
            }
        }
    }

    // MARK: - Weak twos

    private var weakTwoSection: some View {
        Section("Weak Two Openings") {
            Toggle("Enable Weak Twos", isOn: $game.conventionSettings.weakTwoEnabled)
            if game.conventionSettings.weakTwoEnabled {
                Picker("Style", selection: $game.conventionSettings.weakTwoStyle) {
                    ForEach(WeakTwoStyle.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu)
                SettingDetail(text: game.conventionSettings.weakTwoStyle.detail)

                Picker("2NT Response", selection: $game.conventionSettings.weakTwoResponse) {
                    ForEach(WeakTwoResponse.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu)
                SettingDetail(text: game.conventionSettings.weakTwoResponse.detail)
            }
        }
    }

    // MARK: - 2/1

    private var twoOverOneSection: some View {
        Section("2/1 Game Force") {
            Toggle("Enable 2/1 Game Force", isOn: $game.conventionSettings.twoOverOneEnabled)
            if game.conventionSettings.twoOverOneEnabled {
                Picker("Scope", selection: $game.conventionSettings.twoOverOneScope) {
                    ForEach(TwoOverOneScope.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu)
                SettingDetail(text: game.conventionSettings.twoOverOneScope.detail)

                Picker("1NT Response", selection: $game.conventionSettings.oneNTResponseStyle) {
                    ForEach(OneNTResponseStyle.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                SettingDetail(text: game.conventionSettings.oneNTResponseStyle.detail)
            }
        }
    }

    // MARK: - Doubles

    private var doubleSection: some View {
        Section("Doubles") {
            Toggle("Takeout Doubles", isOn: $game.conventionSettings.takeoutDoubleEnabled)
            if game.conventionSettings.takeoutDoubleEnabled {
                Stepper("Takeout min HCP: \(game.conventionSettings.takeoutDoubleMinHCP)",
                        value: $game.conventionSettings.takeoutDoubleMinHCP, in: 12...14)
            }

            Toggle("Negative Doubles", isOn: $game.conventionSettings.negativeDoubleEnabled)
            if game.conventionSettings.negativeDoubleEnabled {
                Picker("Negative through", selection: $game.conventionSettings.negativeDoubleLevel) {
                    ForEach(NegativeDoubleLevel.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu)
                SettingDetail(text: game.conventionSettings.negativeDoubleLevel.detail)
            }

            Toggle("Support Doubles / Redoubles", isOn: $game.conventionSettings.supportDoubles)
            SettingDetail(text: "Opener's double shows exactly 3-card support for responder's suit; a redouble shows the same after a redouble-able auction.")
        }
    }

    // MARK: - Overcalls

    private var overcallSection: some View {
        Section("Overcalls & Two-Suiters") {
            Toggle("Enable Overcalls", isOn: $game.conventionSettings.overcallEnabled)
            if game.conventionSettings.overcallEnabled {
                Picker("Style", selection: $game.conventionSettings.overcallStyle) {
                    ForEach(OvercallStyle.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                SettingDetail(text: game.conventionSettings.overcallStyle.detail)
                Stepper("2-level min HCP: \(game.conventionSettings.overcall2LevelMinHCP)",
                        value: $game.conventionSettings.overcall2LevelMinHCP, in: 8...14)
            }

            Toggle("Michaels Cue Bid", isOn: $game.conventionSettings.michaelsEnabled)
            if game.conventionSettings.michaelsEnabled {
                Picker("Michaels Range", selection: $game.conventionSettings.michaelsStyle) {
                    ForEach(MichaelsStyle.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu)
                SettingDetail(text: game.conventionSettings.michaelsStyle.detail)
            }

            Toggle("Unusual 2NT", isOn: $game.conventionSettings.unusual2NTEnabled)
        }
    }

    // MARK: - Competitive gadgets

    private var competitiveSection: some View {
        Section("Competitive Gadgets") {
            Picker("Defense to 1NT", selection: $game.conventionSettings.ntDefense) {
                ForEach(NTDefense.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.menu)
            SettingDetail(text: game.conventionSettings.ntDefense.detail)

            Picker("Lebensohl", selection: $game.conventionSettings.lebensohl) {
                ForEach(LebensohlSetting.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.menu)
            SettingDetail(text: game.conventionSettings.lebensohl.detail)

            Toggle("Drury", isOn: $game.conventionSettings.druryEnabled)
            if game.conventionSettings.druryEnabled {
                Picker("Drury Style", selection: $game.conventionSettings.druryStyle) {
                    ForEach(DruryStyle.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu)
                SettingDetail(text: game.conventionSettings.druryStyle.detail)
            }
        }
    }

    // MARK: - Constructive gadgets

    private var constructiveSection: some View {
        Section("Minor Suit Bidding") {
            Picker("Minor Raises", selection: $game.conventionSettings.minorRaiseStyle) {
                ForEach(MinorRaiseStyle.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            SettingDetail(text: game.conventionSettings.minorRaiseStyle.detail)
        }
    }

    // MARK: - Display

    private var displaySection: some View {
        Section("Display") {
            Toggle("Alt suit colors (♣ blue / ♦ orange)", isOn: $game.conventionSettings.useAlternateColors)
        }
    }

    private var resetSection: some View {
        Section {
            Button("Reset to Defaults", role: .destructive) {
                game.conventionSettings = ConventionSettings.defaults
            }
        }
    }
}
