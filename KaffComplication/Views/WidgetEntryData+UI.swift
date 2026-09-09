import KaffCore
import SwiftUI

/// Textes et teinte communs aux quatre familles.
extension WidgetEntryData {
    static let openAppLabel = "Ouvrir Kaff"

    /// « — » sans snapshot, sinon le nombre entier de mg.
    var valueText: String { hasData ? Formatters.mgValue(milligrams) : "—" }
    /// Étiquette « mg » logée dans l'ouverture de l'anneau ou dans la jauge du coin.
    var unitLabel: String { "mg" }
    /// « 142 mg » pour les familles à une ligne (rectangulaire, inline) ; espace insécable : le nombre ne se sépare
    /// jamais de son unité.
    var valueWithUnit: String { "\(valueText)\u{A0}\(unitLabel)" }
    /// Gris « anneau vide » sans snapshot ou à zéro, sinon la couleur de statut (comme Home).
    var tint: Color { hasData && milligrams >= 0.5 ? status.color : Theme.idle }
    var ringProgress: Double { limitMg > 0 ? min(milligrams / limitMg, 1) : 0 }
    var ringOverflow: Double { limitMg > 0 ? max(milligrams / limitMg - 1, 0) : 0 }
    var sleepText: String { isSleepReady ? "Sommeil OK" : "Sommeil \(Formatters.time(sleepReadyAt))" }
    /// Ligne secondaire du rectangulaire : le sommeil, ou « Ouvrir Kaff » quand le snapshot est obsolète (spec §8).
    var secondaryText: String { isStale ? Self.openAppLabel : sleepText }
    /// Suffixe de l'inline après les mg : le statut, ou « Ouvrir Kaff » quand le snapshot est obsolète.
    var inlineSuffix: String { isStale ? Self.openAppLabel : status.label }
    var accessibilityText: String {
        hasData ? "\(valueText) milligrammes, \(status.accessibilityLabel), \(secondaryText)" : Self.openAppLabel
    }
}
