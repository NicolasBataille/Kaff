import KaffCore
import SwiftUI

/// Section Notifications (spec §7.6) : deux rappels indépendants, la prochaine occurrence planifiée sous chacun.
/// Refus système : interrupteurs grisés et éteints, chemin vers Réglages › Notifications (spec §9).
struct NotificationSettingsSection: View {
    @Environment(AppModel.self) private var model

    private var profile: UserProfile { model.profile }
    private var isDenied: Bool { model.notificationAuthorization == .denied }

    /// Les deux interrupteurs passent par `setNotifications(sleepReady:lastIntake:)`, qui présente la demande
    /// système à la première activation ; un refus laisse les drapeaux à faux, donc l'interrupteur retombe.
    private var sleepReady: Binding<Bool> {
        Binding(get: { profile.notifySleepReady && !isDenied }, set: { on in
            Task { await model.setNotifications(sleepReady: on, lastIntake: profile.notifyLastIntake) }
        })
    }

    private var lastIntake: Binding<Bool> {
        Binding(get: { profile.notifyLastIntake && !isDenied }, set: { on in
            Task { await model.setNotifications(sleepReady: profile.notifySleepReady, lastIntake: on) }
        })
    }

    var body: some View {
        Section("Notifications") {
            toggle("OK pour dormir", symbol: "moon.stars.fill", tint: Theme.sleep, isOn: sleepReady)
                .sensoryFeedback(.success, trigger: profile.notifySleepReady) { _, new in new }
            if sleepReady.wrappedValue {
                nextFootnote(for: .sleepReady)
            }
            toggle("Dernière prise avant le coucher", symbol: "cup.and.saucer.fill", tint: Theme.accent, isOn: lastIntake)
                .sensoryFeedback(.success, trigger: profile.notifyLastIntake) { _, new in new }
            if lastIntake.wrappedValue {
                nextFootnote(for: .lastIntake)
            }
            if isDenied {
                SettingsFootnote("Notifications refusées. Réglages › Notifications › Kaff pour les activer.")
            }
        }
    }

    private func toggle(_ title: LocalizedStringKey, symbol: String, tint: Color, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol).foregroundStyle(tint)
            }
        }
        .tint(tint)
        .disabled(isDenied)
    }

    /// « Prochain rappel 19:05 · Espresso 63 mg » (dernière prise), « Prochaine notification 16:47 » (OK pour dormir),
    /// ou « Rien à planifier aujourd'hui » quand le plan courant ne contient rien de ce genre.
    @ViewBuilder private func nextFootnote(for kind: PlannedNotification.Kind) -> some View {
        if let item = model.plannedNotifications.first(where: { $0.kind == kind }) {
            let time = Formatters.time(item.fireAt)
            switch kind {
            case .sleepReady:
                SettingsFootnote("Prochaine notification \(time)")
            case .lastIntake:
                let drink = model.referenceDrink
                SettingsFootnote("Prochain rappel \(time) · \(drink.name) \(Formatters.mg(item.milligrams ?? drink.milligrams))")
            }
        } else {
            SettingsFootnote("Rien à planifier aujourd'hui")
        }
    }
}
