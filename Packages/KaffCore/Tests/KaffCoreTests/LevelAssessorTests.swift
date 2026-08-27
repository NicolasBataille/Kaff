import Foundation
import Testing
@testable import KaffCore

private func assessor(_ mutate: (inout UserProfile) -> Void = { _ in }) -> LevelAssessor {
    var p = UserProfile.default
    mutate(&p)
    return LevelAssessor(profile: p, calendar: TestClock.calendar)
}

@Test func noDosesIsOkAndSleepReadyNow() {
    let now = TestClock.date(10)
    let a = assessor().assess(doses: [], at: now)
    #expect(a.currentMg == 0)
    #expect(a.dailyTotalMg == 0)
    #expect(a.status == .ok)
    #expect(a.reason == .none)
    #expect(a.sleepReadyAt == now)
    #expect(a.isSleepReady)
}

@Test func bigDoseOneHourAgoIsHighForPeak() {
    let now = TestClock.date(10)
    let a = assessor().assess(doses: [CaffeineDose(date: TestClock.date(9), milligrams: 250)], at: now)
    #expect(abs(a.currentMg - 222) < 2)          // 250 × 0,889 (voir modèle PK à t = 1 h)
    #expect(a.peakStatus == .high)
    #expect(a.reason == .peak)
}

@Test func mediumDoseIsElevatedForPeak() {
    let now = TestClock.date(10)
    let a = assessor().assess(doses: [CaffeineDose(date: TestClock.date(9), milligrams: 150)], at: now)
    #expect(a.peakStatus == .elevated)           // 133 mg / 200 = 0,67 ≥ 0,6
    #expect(a.status == .elevated)
}

@Test func dailyTotalCountsSinceFourAM() {
    let now = TestClock.date(20)
    let doses = [
        CaffeineDose(date: TestClock.date(day: 9, 23), milligrams: 20),   // veille, hors journée
        CaffeineDose(date: TestClock.date(2), milligrams: 20),            // 02:00 → journée de la veille
        CaffeineDose(date: TestClock.date(8), milligrams: 140),
        CaffeineDose(date: TestClock.date(10), milligrams: 140),
        CaffeineDose(date: TestClock.date(12), milligrams: 140),
        CaffeineDose(date: TestClock.date(21), milligrams: 999),          // futur, ignoré
    ]
    let a = assessor { $0.bedtimeLimitMg = 100 }.assess(doses: doses, at: now)
    #expect(a.dailyTotalMg == 420)
    #expect(a.dailyStatus == .high)
    #expect(a.peakStatus == .ok)                 // ≈ 114 mg / 200 = 0,57
    #expect(a.bedtimeStatus == .elevated)        // ≈ 74 mg / 100
    #expect(a.reason == .daily)
}

@Test func bedtimeProjectionAndSleepReady() {
    let now = TestClock.date(20)
    let a = assessor().assess(doses: [CaffeineDose(date: TestClock.date(19), milligrams: 200)], at: now)
    #expect(a.bedtime == TestClock.date(23))
    #expect(abs(a.projectedBedtimeMg - 118) < 2)  // 200 × 0,59 à t = 4 h
    #expect(a.bedtimeStatus == .high)
    #expect(a.reason == .bedtime)
    // < 50 mg à t ≈ 10,2 h après 19:00 → ≈ 05:12
    let expected = TestClock.date(19).addingTimeInterval(10.204 * 3600)
    #expect(abs(a.sleepReadyAt.timeIntervalSince(expected)) < 120)
    #expect(!a.isSleepReady)
}

@Test func afterBedtimeProjectionIsCurrentLevel() {
    let now = TestClock.date(23, 30)
    let a = assessor().assess(doses: [CaffeineDose(date: TestClock.date(22), milligrams: 100)], at: now)
    #expect(a.bedtime == now)
    #expect(a.projectedBedtimeMg == a.currentMg)
}

@Test func sleepReadyIsAfterPeakEvenIfCurrentlyLow() {
    let now = TestClock.date(20)
    let a = assessor().assess(doses: [CaffeineDose(date: now, milligrams: 100)], at: now)
    #expect(a.currentMg == 0)
    #expect(a.sleepReadyAt > now)
}

@Test func priorityWhenTwoChecksAreHighIsPeakThenBedtimeThenDaily() {
    let now = TestClock.date(22)
    let a = assessor().assess(doses: [CaffeineDose(date: TestClock.date(21), milligrams: 300)], at: now)
    #expect(a.peakStatus == .high && a.bedtimeStatus == .high)
    #expect(a.reason == .peak)
}
