import KaffCore
import SwiftUI

/// Ligne d'un réglage numérique : valeur teintée qui compte (`numericText`) et ouvre son cadran couronne.
struct SettingRowLink: View {
    let key: SettingKey

    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationLink(value: Route.setting(key)) {
            LabeledContent {
                Text(key.format(key.value(in: model.profile)))
                    .monospacedDigit()
                    .foregroundStyle(key.tint)
                    .contentTransition(.numericText())
            } label: {
                Label(key.title, systemImage: key.symbol)
            }
        }
        .animation(.default, value: model.profile)
    }
}

/// Note grise sous une ligne ; ses chiffres comptent quand le profil ou le plan de notifications change.
struct SettingsFootnote: View {
    private let key: LocalizedStringKey

    @Environment(AppModel.self) private var model

    init(_ key: LocalizedStringKey) { self.key = key }

    var body: some View {
        Text(key)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.default, value: model.profile)
            .animation(.default, value: model.plannedNotifications)
    }
}
