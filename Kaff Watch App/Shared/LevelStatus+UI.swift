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
    var label: String {
        switch self {
        case .none: "Niveau correct"
        case .peak: "Pic trop haut"
        case .daily: "Cumul du jour dépassé"
        case .bedtime: "Trop pour bien dormir"
        }
    }
}
