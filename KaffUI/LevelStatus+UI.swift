import KaffCore
import SwiftUI

extension LevelStatus {
    var color: Color {
        switch self {
        case .ok: Theme.Status.ok
        case .elevated: Theme.Status.elevated
        case .high: Theme.Status.high
        }
    }

    var label: String {
        switch self {
        case .ok: "OK"
        case .elevated: "Élevé"
        case .high: "Trop haut"
        }
    }

    var symbol: String {
        switch self {
        case .ok: "checkmark.circle.fill"
        case .elevated: "exclamationmark.circle.fill"
        case .high: "exclamationmark.triangle.fill"
        }
    }

    /// Libellé VoiceOver (« niveau OK »).
    var accessibilityLabel: String { "niveau \(label)" }
}

extension LevelReason {
    var label: String { label(for: .high) }

    /// Libellé nuancé selon la gravité : « Pic élevé » (elevated) vs « Pic trop haut » (high).
    func label(for status: LevelStatus) -> String {
        switch (self, status) {
        case (.none, _), (_, .ok): "Niveau correct"
        case (.peak, .elevated): "Pic élevé"
        case (.peak, .high): "Pic trop haut"
        case (.daily, .elevated): "Cumul du jour élevé"
        case (.daily, .high): "Cumul du jour dépassé"
        case (.bedtime, .elevated): "Risque pour le sommeil"
        case (.bedtime, .high): "Trop pour bien dormir"
        }
    }
}
