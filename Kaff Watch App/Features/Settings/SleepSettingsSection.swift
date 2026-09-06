import KaffCore
import SwiftUI

/// Section Sommeil : coucher déduit de Santé (spec §5.1) ou manuel. La ligne « Coucher » montre la valeur
/// effective et sa provenance, et ouvre toujours le cadran manuel (repli visible quand Santé n'a aucune nuit).
struct SleepSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var profile: UserProfile { model.profile }
    private var state: AppModel.HealthBedtimeState { model.healthBedtimeState }

    /// La feuille d'autorisation sommeil part de ce tap (spec §7.5) ; l'interrupteur suit le profil une fois répondu.
    private var usesHealthBedtime: Binding<Bool> {
        Binding(get: { profile.usesHealthBedtime }, set: { on in
            Task { on ? await model.enableHealthBedtime() : await model.disableHealthBedtime() }
        })
    }

    var body: some View {
        Section("Sommeil") {
            Toggle("Coucher depuis Santé", isOn: usesHealthBedtime)
                .tint(Theme.sleep)
            bedtimeRow
            if state == .noNights {
                SettingsFootnote("Aucune nuit trouvée dans Santé sur la montre. Le coucher manuel est utilisé.")
            }
            SettingRowLink(key: .bedtimeLimit)
        }
    }

    private var bedtimeRow: some View {
        NavigationLink(value: Route.bedtime) {
            LabeledContent {
                Text(Formatters.time(profile.effectiveBedtime))
                    .monospacedDigit()
                    .foregroundStyle(Theme.sleep)
                    .contentTransition(.numericText())
                    .animation(Motion.snap(reduceMotion: reduceMotion), value: profile.effectiveBedtime)
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Coucher")
                        sourceCaption
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .animation(.default, value: state)
                } icon: {
                    Image(systemName: "moon.zzz.fill")
                }
            }
        }
        // La valeur Santé arrive (ou change) : le nombre compte avec un spring et la montre confirme.
        .sensoryFeedback(.success, trigger: state) { old, new in
            if case .inferred = new { return old != new }
            return false
        }
    }

    @ViewBuilder private var sourceCaption: some View {
        switch state {
        case .inferred(let nights): Text("Médiane de \(nights) nuits · Santé")
        case .off, .noNights: Text("Manuel")
        }
    }
}
