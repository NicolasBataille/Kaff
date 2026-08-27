import Foundation

/// Modèle à un compartiment, absorption et élimination de premier ordre (courbe de Bateman).
/// Retourne des **mg dans l'organisme** (pas une concentration).
public struct PharmacokineticModel: Hashable, Sendable {
    /// Constante d'absorption ka (h⁻¹). Avec t½ = 5 h, tmax ≈ 44 min, dans la fourchette 30–60 min.
    /// Source: tmax caféine 30–60 min (EFSA 2015) ; ka choisi pour tmax = ln(ka/ke)/(ka−ke) ≈ 0,74 h.
    public static let absorptionRatePerHour = 5.0

    public let halfLifeHours: Double

    public init(halfLifeHours: Double) {
        self.halfLifeHours = halfLifeHours
    }

    /// ke = ln 2 / t½ (h⁻¹).
    public var eliminationRatePerHour: Double { log(2) / halfLifeHours }

    /// Instant du pic après une prise (h).
    public var timeToPeakHours: Double {
        let ka = Self.absorptionRatePerHour, ke = eliminationRatePerHour
        return log(ka / ke) / (ka - ke)
    }

    /// Quantité restante d'une dose `dose` mg prise il y a `t` heures.
    public func amount(dose: Double, hoursSince t: Double) -> Double {
        guard t > 0, dose > 0 else { return 0 }
        let ka = Self.absorptionRatePerHour, ke = eliminationRatePerHour
        return dose * ka / (ka - ke) * (exp(-ke * t) - exp(-ka * t))
    }

    /// Superposition linéaire de toutes les doses à l'instant `date`.
    public func amount(doses: [CaffeineDose], at date: Date) -> Double {
        doses.reduce(0) { total, dose in
            total + amount(dose: dose.milligrams, hoursSince: date.timeIntervalSince(dose.date) / 3600)
        }
    }
}
