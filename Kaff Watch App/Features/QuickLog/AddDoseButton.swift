import SwiftUI

/// Bouton « Ajouter » : se transforme en coche avec haptique `.success`, puis `onSuccess` après un court délai ;
/// en cas d'échec, haptique `.error` et bouton de nouveau actif (l'alerte est gérée par `RootView`).
/// L'échec a son propre déclencheur (`failureCount`) : `phase` revient à `.idle` dans la même transaction,
/// et SwiftUI ne verrait aucun changement.
struct AddDoseButton: View {
    enum Phase: Equatable { case idle, saving, done }

    /// Exécute l'enregistrement ; renvoie `true` en cas de succès.
    let action: () async -> Bool
    let onSuccess: () -> Void

    @State private var phase: Phase = .idle
    @State private var failureCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isDone: Bool { phase == .done }

    var body: some View {
        Button {
            Task { await run() }
        } label: {
            label
        }
        .buttonStyle(.glassProminent)
        .controlSize(.small)
        .tint(tint)
        .disabled(phase != .idle)
        .animation(Motion.snap(reduceMotion: reduceMotion), value: phase)
        .sensoryFeedback(.success, trigger: phase) { _, new in new == .done }
        .sensoryFeedback(.error, trigger: failureCount)
        .accessibilityLabel(isDone ? "Dose ajoutée" : "Ajouter la dose")
    }

    private var tint: Color { isDone ? Theme.Status.ok : Theme.accent }

    private var label: some View {
        Label(isDone ? "Ajouté" : "Ajouter", systemImage: isDone ? "checkmark" : "plus")
            .font(.body.weight(.semibold))
            .contentTransition(.symbolEffect(.replace))
            .frame(maxWidth: .infinity)
            .opacity(phase == .saving ? 0.6 : 1)
    }

    private func run() async {
        phase = .saving
        guard await action() else {
            failureCount += 1
            phase = .idle
            return
        }
        phase = .done
        try? await Task.sleep(for: Theme.confirmationDelay)
        onSuccess()
    }
}
