import SwiftUI

/// Écran d'accueil (spec §9, brief §3.7) : avant la première demande, un bouton « Autoriser » présente la
/// feuille Santé ; après un refus, HealthKit ne la ré-affiche jamais, on indique le chemin Réglages.
struct AuthorizationView: View {
    @Environment(AppModel.self) private var model
    @State private var isBusy = false

    private var state: AppModel.AuthorizationState { model.authorization }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .repeat(2), isActive: !isBusy)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Kaff enregistre vos doses de caféine dans Santé et y lit votre poids pour ses seuils.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                switch state {
                case .notDetermined:
                    button("Autoriser Santé", systemImage: "checkmark.shield.fill") { await model.requestAccess() }
                case .denied:
                    Text("Autorisez l'écriture de « Caféine » : Réglages › Santé › Apps › Kaff.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    button("Réessayer", systemImage: "arrow.clockwise") { await model.start() }
                case .unknown, .authorized, .unavailable:
                    EmptyView()
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Kaff")
    }

    private var title: LocalizedStringKey {
        switch state {
        case .unavailable: "Santé indisponible"
        case .denied: "Accès Santé requis"
        default: "Bienvenue dans Kaff"
        }
    }

    private func button(_ title: LocalizedStringKey, systemImage: String,
                        action: @escaping () async -> Void) -> some View {
        Button {
            isBusy = true
            Task {
                await action()
                isBusy = false
            }
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .tint(Theme.accent)
        .disabled(isBusy)
        .padding(.top, 4)
    }
}
