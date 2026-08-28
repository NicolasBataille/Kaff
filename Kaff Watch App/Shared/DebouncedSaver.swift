import Foundation

/// Sauvegarde différée d'un cadran couronne : chaque cran replanifie l'écriture (`delay`), `flush()` à la disparition
/// exécute immédiatement ce qui est en attente. Évite une écriture du profil et un rechargement des complications par cran.
@MainActor
final class DebouncedSaver {
    /// Source: choix produit — assez court pour paraître immédiat, assez long pour absorber une rotation continue.
    static let defaultDelay: Duration = .milliseconds(250)

    private let delay: Duration
    private var task: Task<Void, Never>?
    private var pending: (@MainActor () async -> Void)?

    init(delay: Duration = DebouncedSaver.defaultDelay) {
        self.delay = delay
    }

    /// Remplace toute sauvegarde en attente par `save`, exécutée après `delay` sans nouvel appel.
    func schedule(_ save: @escaping @MainActor () async -> Void) {
        task?.cancel()
        pending = save
        task = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await runPending()
        }
    }

    /// Exécute sans attendre la sauvegarde en attente, s'il y en a une.
    func flush() {
        task?.cancel()
        task = nil
        guard pending != nil else { return }
        Task { await runPending() }
    }

    private func runPending() async {
        guard let save = pending else { return }
        pending = nil
        await save()
    }
}
