import Foundation

/// Modèle à un compartiment, absorption et élimination de premier ordre (courbe de Bateman).
/// Retourne des **mg dans l'organisme** (pas une concentration).
/// Source: Seng 2009 (meilleur ajustement : 1 compartiment, absorption et élimination de 1er ordre) ;
/// biodisponibilité orale ≈ 100 % (Blanchard & Sawers 1983) donc D = quantité absorbée.
public struct PharmacokineticModel: Hashable, Sendable {
    /// Constante d'absorption ka (h⁻¹).
    /// Source: tmax 30–120 min (EFSA 2015), ≈ 42 min pour le café (Liguori 1997) ; ka publiés 1,3–2,4 h⁻¹ gélule,
    /// 3,2–4,0 h⁻¹ gomme (Kamimori 2002) — 5 h⁻¹ calé sur une boisson chaude ; tmax résultant 34–52 min sur t½ 2–10 h.
    public static let absorptionRatePerHour = 5.0

    public let halfLifeHours: Double

    /// Invariant : `halfLifeHours` > 0 et ≠ ln2/ka (≈ 0,139 h) ; garanti par `UserProfile.Bounds.halfLifeHours` (2–10 h).
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

    /// Fraction de la dose présente au pic (Cmax/D) ; 0,90 pour t½ = 5 h.
    public var peakFraction: Double { amount(dose: 1, hoursSince: timeToPeakHours) }

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
