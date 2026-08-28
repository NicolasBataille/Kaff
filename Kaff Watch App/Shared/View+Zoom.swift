import SwiftUI

extension View {
    /// Déclare la vue comme source du morphing `.zoom` quand l'espace de noms est disponible dans l'environnement.
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}
