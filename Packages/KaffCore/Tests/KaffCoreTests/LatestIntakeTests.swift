import Foundation
import Testing
@testable import KaffCore

/// Profil par défaut : coucher 23:00, seuil coucher 35 mg, t½ 5 h.
private let assessor = LevelAssessor(profile: .default, calendar: TestClock.calendar)
private let bedtime = TestClock.date(23)
private let noon = TestClock.date(14)

/// `A_total(coucher)` avec une dose de `mg` prise à `t`, en plus des doses déjà passées à `now`.
private func projected(_ mg: Double, takenAt t: Date, doses: [CaffeineDose] = [], now: Date) -> Double {
    let past = doses.filter { $0.date <= now }
    return assessor.model.amount(doses: past + [CaffeineDose(date: t, milligrams: mg)], at: bedtime)
}

/// Spec §5.2 : 63 mg seuls → `ln(préfacteur × 63/35)/ke ≈ 4,44 h` avant le coucher (≈ 18:33).
@Test func espressoAloneLandsAboutFourAndAHalfHoursBeforeBed() throws {
    let model = assessor.model
    let ke = model.eliminationRatePerHour
    // Préfacteur ka/(ka − ke) ≈ 1,0285 à t½ 5 h, mesuré sur le modèle en phase d'élimination.
    let prefactor = model.amount(dose: 1, hoursSince: 10) / exp(-ke * 10)
    #expect(abs(prefactor - 1.0285) < 0.001)
    let delayHours = log(prefactor * 63 / 35) / ke
    let expected = bedtime.addingTimeInterval(-delayHours * 3600)
    let t = try #require(assessor.latestIntakeDate(milligrams: 63, doses: [], from: noon))
    #expect(abs(t.timeIntervalSince(expected)) < 180)
    #expect(t >= noon)
}

@Test func returnedInstantIsTheLastMinuteUnderTheLimit() throws {
    let t = try #require(assessor.latestIntakeDate(milligrams: 63, doses: [], from: noon))
    #expect(projected(63, takenAt: t, now: noon) < 35)
    #expect(projected(63, takenAt: t.addingTimeInterval(120), now: noon) >= 35)
}

@Test func alreadyOverTheLimitAtNowIsNil() {
    let doses = [CaffeineDose(date: TestClock.date(18), milligrams: 200)]
    let now = TestClock.date(18, 30)
    #expect(projected(63, takenAt: now, doses: doses, now: now) >= 35)
    #expect(assessor.latestIntakeDate(milligrams: 63, doses: doses, from: now) == nil)
}

@Test func bedtimeAlreadyPassedInCaffeineDayIsNil() {
    #expect(assessor.latestIntakeDate(milligrams: 63, doses: [], from: TestClock.date(23, 30)) == nil)
}

@Test func nowPastBedtimeMinusPeakIsNil() {
    // tmax ≈ 44 min à t½ 5 h → borne ≈ 22:16 ; 22:45 est au-delà : intervalle vide.
    let upper = bedtime.addingTimeInterval(-assessor.model.timeToPeakHours * 3600)
    let now = TestClock.date(22, 45)
    #expect(now > upper)
    #expect(assessor.latestIntakeDate(milligrams: 63, doses: [], from: now) == nil)
}

@Test func smallDosePassesEverywhereAndReturnsBedtimeMinusPeak() {
    let upper = bedtime.addingTimeInterval(-assessor.model.timeToPeakHours * 3600)
    #expect(projected(20, takenAt: upper, now: noon) < 35)
    #expect(assessor.latestIntakeDate(milligrams: 20, doses: [], from: noon) == upper)
}

@Test func zeroBedtimeLimitDisablesTheSearch() {
    let limits = AssessmentLimits(halfLifeHours: 5, bedtime: ClockTime(hour: 23, minute: 0),
                                  peakLimitMg: 180, dailyLimitMg: 400, bedtimeLimitMg: 0)
    let a = LevelAssessor(limits: limits, calendar: TestClock.calendar)
    #expect(a.latestIntakeDate(milligrams: 63, doses: [], from: noon) == nil)
}

@Test func futureDosesAreIgnored() throws {
    let future = [CaffeineDose(date: TestClock.date(20), milligrams: 999)]
    let withFuture = try #require(assessor.latestIntakeDate(milligrams: 63, doses: future, from: noon))
    let without = try #require(assessor.latestIntakeDate(milligrams: 63, doses: [], from: noon))
    #expect(withFuture == without)
}
