import Foundation
import Testing
@testable import KaffCore

private let model = PharmacokineticModel(halfLifeHours: 5)

@Test func nothingBeforeIntake() {
    #expect(model.amount(dose: 100, hoursSince: -1) == 0)
    #expect(model.amount(dose: 100, hoursSince: 0) == 0)
}

@Test func peakOccursAround44Minutes() {
    // tmax = ln(ka/ke)/(ka−ke) avec ka = 5, ke = ln2/5 ≈ 0,1386 → 0,738 h
    #expect(abs(model.timeToPeakHours - 0.738) < 0.005)
    let samples = stride(from: 0.0, through: 3.0, by: 0.01).map { ($0, model.amount(dose: 100, hoursSince: $0)) }
    let peak = samples.max { $0.1 < $1.1 }!
    #expect(abs(peak.0 - model.timeToPeakHours) < 0.02)
}

@Test func peakIsAbout90PercentOfDose() {
    #expect(abs(model.amount(dose: 100, hoursSince: model.timeToPeakHours) - 90.3) < 0.5)
}

@Test func lateDecayFollowsEliminationWithBatemanPrefactor() {
    // Asymptote = D·ka/(ka−ke)·e^(−ke·t) : le préfacteur 1,0285 ne disparaît pas.
    // À 10 h : 100 × 1,0285 × e^(−ln2·10/5) = 25,7 mg (et non 25,0).
    #expect(abs(model.amount(dose: 100, hoursSince: 10) - 25.7) < 0.2)
}

@Test func halfLifeChangesElimination() {
    let fast = PharmacokineticModel(halfLifeHours: 2.5)
    #expect(fast.amount(dose: 100, hoursSince: 10) < model.amount(dose: 100, hoursSince: 10))
}

@Test func dosesSuperpose() {
    let t0 = Date(timeIntervalSince1970: 0)
    let doses = [
        CaffeineDose(date: t0, milligrams: 100),
        CaffeineDose(date: t0.addingTimeInterval(3600), milligrams: 50),
    ]
    let at = t0.addingTimeInterval(2 * 3600)
    let expected = model.amount(dose: 100, hoursSince: 2) + model.amount(dose: 50, hoursSince: 1)
    #expect(abs(model.amount(doses: doses, at: at) - expected) < 1e-9)
}
