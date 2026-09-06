import Foundation
import Testing
@testable import KaffCore

/// Profil par défaut : coucher 23:00, seuil coucher 35 mg, t½ 5 h.
private let limits = AssessmentLimits(profile: .default)
private let assessor = LevelAssessor(limits: limits, calendar: TestClock.calendar)
/// Espresso du catalogue (spec §5.2).
private let espressoMg = 63.0

private func plan(doses: [CaffeineDose], now: Date, sleepReady: Bool = true, lastIntake: Bool = true) -> [PlannedNotification] {
    NotificationPlanner.plan(doses: doses, limits: limits, referenceMg: espressoMg,
                             wantsSleepReady: sleepReady, wantsLastIntake: lastIntake,
                             now: now, calendar: TestClock.calendar)
}

@Test func nothingWhenBothOptionsAreOff() {
    let doses = [CaffeineDose(date: TestClock.date(9), milligrams: 100)]
    #expect(plan(doses: doses, now: TestClock.date(12), sleepReady: false, lastIntake: false).isEmpty)
}

/// 100 mg à 09:00 laissent ≈ 14,8 mg à 23:00 : un espresso passe encore jusqu'à ≈ 14:35, et le niveau
/// repasse sous 35 mg vers 16:47 — les deux notifications tombent le jour même, dernière prise en premier.
@Test func nominalCaseYieldsBothSortedByDate() throws {
    let doses = [CaffeineDose(date: TestClock.date(9), milligrams: 100)]
    let now = TestClock.date(12)
    let result = plan(doses: doses, now: now)
    #expect(result.count == 2)
    #expect(result.map(\.fireAt) == result.map(\.fireAt).sorted())
    let lastIntake = try #require(result.first { $0.kind == .lastIntake })
    let sleepReady = try #require(result.first { $0.kind == .sleepReady })
    #expect(lastIntake.milligrams == espressoMg)
    #expect(sleepReady.milligrams == nil)
    #expect(lastIntake.fireAt == assessor.latestIntakeDate(milligrams: espressoMg, doses: doses, from: now))
    #expect(sleepReady.fireAt == assessor.sleepReadyDate(doses: doses, from: now))
    #expect(lastIntake.fireAt > now.addingTimeInterval(60))
    #expect(sleepReady.fireAt > now.addingTimeInterval(60))
    #expect(sleepReady.fireAt < assessor.day.nextStart(after: now))
}

@Test func eachOptionIsIndependent() {
    let doses = [CaffeineDose(date: TestClock.date(9), milligrams: 100)]
    let now = TestClock.date(12)
    #expect(plan(doses: doses, now: now, sleepReady: true, lastIntake: false).map(\.kind) == [.sleepReady])
    #expect(plan(doses: doses, now: now, sleepReady: false, lastIntake: true).map(\.kind) == [.lastIntake])
}

@Test func sleepReadyOmittedWhenAlreadyUnderTheLimit() {
    let result = plan(doses: [], now: TestClock.date(12), lastIntake: false)
    #expect(result.isEmpty)
}

/// 400 mg à 22:00 : le seuil n'est repassé que vers 15:50 le lendemain, bien après 04:00 — pas de vibration la nuit.
@Test func sleepReadyOmittedWhenAfterNextDayStart() {
    let doses = [CaffeineDose(date: TestClock.date(22), milligrams: 400)]
    let now = TestClock.date(22, 30)
    #expect(assessor.sleepReadyDate(doses: doses, from: now) >= assessor.day.nextStart(after: now))
    #expect(plan(doses: doses, now: now).contains { $0.kind == .sleepReady } == false)
}

@Test func lastIntakeOmittedWhenNoInstantRemains() {
    let result = plan(doses: [], now: TestClock.date(23, 30))
    #expect(result.contains { $0.kind == .lastIntake } == false)
}

/// À l'instant même de la dernière prise possible, la recomputation retombe à moins d'une minute : rien à planifier.
@Test func lastIntakeOmittedWhenWithinMinimumLead() throws {
    let t0 = try #require(assessor.latestIntakeDate(milligrams: espressoMg, doses: [], from: TestClock.date(14)))
    let recomputed = try #require(assessor.latestIntakeDate(milligrams: espressoMg, doses: [], from: t0))
    #expect(recomputed <= t0.addingTimeInterval(NotificationPlanner.minimumLeadSeconds))
    #expect(plan(doses: [], now: t0).contains { $0.kind == .lastIntake } == false)
}

@Test func kindsHaveStableIdentifiers() {
    #expect(PlannedNotification.Kind.sleepReady.rawValue == "sleepReady")
    #expect(PlannedNotification.Kind.lastIntake.rawValue == "lastIntake")
    #expect(PlannedNotification.Kind.allCases.count == 2)
}
