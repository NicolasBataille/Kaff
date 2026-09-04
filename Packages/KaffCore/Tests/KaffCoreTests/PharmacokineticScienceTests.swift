import Foundation
import Testing
@testable import KaffCore

/// Cohérence du modèle de Bateman avec la littérature (M5.6), sur toute la plage de demi-vies autorisée.
/// Valeurs attendues (ka = 5 h⁻¹) : t½ 2 h → tmax 34,4 min, pic 0,820 ; 5 h → 44,3 min, 0,903 ; 10 h → 52,1 min, 0,942.
@Test(arguments: [2.0, 3.0, 5.0, 8.0, 10.0])
func peakTimeAndFractionStayInPublishedRanges(halfLife: Double) {
    let model = PharmacokineticModel(halfLifeHours: halfLife)
    // Source: EFSA 2015, tmax 30–120 min.
    #expect((0.5...2.0).contains(model.timeToPeakHours), "tmax \(model.timeToPeakHours) h pour t½ \(halfLife) h")
    // Cmax/D d'une absorption rapide : 82–94 % sur 2–10 h, jamais 100 % (élimination pendant l'absorption).
    #expect((0.80...0.95).contains(model.peakFraction), "pic \(model.peakFraction) pour t½ \(halfLife) h")
}

@Test func peakFractionIsTheAmountAtPeakForAUnitDose() {
    let model = PharmacokineticModel(halfLifeHours: 5)
    #expect(abs(model.peakFraction - model.amount(dose: 1, hoursSince: model.timeToPeakHours)) < 1e-12)
    #expect(abs(model.peakFraction - 0.903) < 0.001)
}

/// Bilan de masse : ∫ ke·A(t) dt = D — tout ce qui est absorbé est éliminé, rien n'est perdu ni créé.
/// Analytiquement D·ka/(ka−ke)·ke·(1/ke − 1/ka) = D ; la biodisponibilité orale ≈ 100 %
/// (Blanchard & Sawers 1983, F = 108 ± 3,6 %) justifie de prendre D = quantité absorbée.
@Test func eliminatedMassEqualsDoseOverTheWholeCurve() {
    let model = PharmacokineticModel(halfLifeHours: 5)
    let dose = 100.0
    let step = 0.005
    var eliminated = 0.0
    var t = 0.0
    while t < 200 {
        // Point milieu : A est C² sur ]0, ∞[, l'erreur est O(step²) ≪ 0,5 %.
        eliminated += model.eliminationRatePerHour * model.amount(dose: dose, hoursSince: t + step / 2) * step
        t += step
    }
    #expect(abs(eliminated - dose) < 0.005 * dose)
}
