import KaffCore
import SwiftUI

/// Textes et teinte communs aux quatre familles.
extension WidgetEntryData {
    static let openAppLabel = "Ouvrir Kaff"

    /// « — » sans snapshot, sinon le nombre entier de mg.
    var valueText: String { hasData ? Formatters.mgValue(milligrams) : "—" }
    /// Gris « anneau vide » sans snapshot ou à zéro, sinon la couleur de statut (comme Home).
    var tint: Color { hasData && milligrams >= 0.5 ? status.color : Theme.idle }
    var ringProgress: Double { limitMg > 0 ? min(milligrams / limitMg, 1) : 0 }
    var ringOverflow: Double { limitMg > 0 ? max(milligrams / limitMg - 1, 0) : 0 }
    var sleepText: String { isSleepReady ? "Sommeil OK" : "Sommeil \(Formatters.time(sleepReadyAt))" }
    var accessibilityText: String {
        hasData ? "\(Formatters.mgValue(milligrams)) milligrammes, \(status.accessibilityLabel), \(sleepText)" : Self.openAppLabel
    }
}
