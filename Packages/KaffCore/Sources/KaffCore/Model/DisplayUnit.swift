import Foundation

/// Unité d'affichage de la complication (spec §5.3, §8) : la quantité dans l'organisme en mg, ou la concentration
/// plasmatique estimée en mg/L (`mg / distributionLitres`). L'anneau ne dépend jamais de l'unité.
public enum DisplayUnit: String, Codable, Hashable, Sendable, CaseIterable {
    case milligrams
    case milligramsPerLitre
}
