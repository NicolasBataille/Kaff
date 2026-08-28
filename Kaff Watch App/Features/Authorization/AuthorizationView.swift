import SwiftUI

/// Écran bloquant quand Santé refuse l'écriture (spec §9, brief §3.7).
struct AuthorizationView: View {
    @Environment(AppModel.self) private var model
    @State private var isRetrying = false

    private var isUnavailable: Bool { model.authorization == .unavailable }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .repeat(2), isActive: !isRetrying)
                    .accessibilityHidden(true)
                Text(isUnavailable ? "Santé indisponible" : "Accès Santé requis")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Kaff enregistre vos doses de caféine dans Santé.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if !isUnavailable {
                    Text("Autorisez l'écriture de « Caféine » : Réglages › Santé › Apps › Kaff.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        isRetrying = true
                        Task {
                            await model.start()
                            isRetrying = false
                        }
                    } label: {
                        Label("Réessayer", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.accent)
                    .disabled(isRetrying)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Kaff")
    }
}
