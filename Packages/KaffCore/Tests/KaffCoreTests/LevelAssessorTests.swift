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
    #expect(a.peakStatus == .elevated)           // 133 mg / 180,6 = 0,74 ≥ 0,6
    #expect(a.status == .elevated)
}

/// EFSA 2015 §5.1.3 : la charge corporelle ne doit pas dépasser le Cmax d'une dose unique à la limite (200 mg).
/// 190 mg = 0,95 × 200 → pic 190 × 0,903 = 171,5 mg < 180,6 mg : jamais haut, échantillonné à la minute sur 3 h.
@Test func singleDoseBelowIntakeLimitNeverReachesHighPeak() {
    let a = assessor()
    let intake = TestClock.date(9)
    let doses = [CaffeineDose(date: intake, milligrams: 0.95 * UserProfile.default.singleDoseLimitMg)]
    for minute in 0...180 {
        let at = intake.addingTimeInterval(Double(minute) * 60)
        #expect(a.assess(doses: doses, at: at).peakStatus != .high, "minute \(minute)")
    }
}

/// 210 mg = 1,05 × 200 → pic 210 × 0,903 = 189,6 mg > 180,6 mg : haut au tmax.
@Test func singleDoseAboveIntakeLimitIsHighAtPeak() {
    let a = assessor()
    let intake = TestClock.date(9)
    let doses = [CaffeineDose(date: intake, milligrams: 1.05 * UserProfile.default.singleDoseLimitMg)]
    let atPeak = intake.addingTimeInterval(a.model.timeToPeakHours * 3600)
    let result = a.assess(doses: doses, at: atPeak)
    #expect(abs(result.currentMg - 189.6) < 0.1)
    #expect(result.peakStatus == .high)
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
    // 140 × 1,0285 × (e^(−0,13863×12) + e^(−0,13863×10) + e^(−0,13863×8)) ≈ 110,8 mg / 180,6 = 0,61 ≥ 0,6
    #expect(a.peakStatus == .elevated)
    #expect(a.bedtimeStatus == .elevated)        // ≈ 74 mg / 100
    #expect(a.reason == .daily)                  // seul .high ; le pic et le coucher ne sont qu'élevés
}

@Test func bedtimeProjectionAndSleepReady() {
    let now = TestClock.date(20)
    let a = assessor().assess(doses: [CaffeineDose(date: TestClock.date(19), milligrams: 200)], at: now)
    #expect(a.bedtime == TestClock.date(23))
    #expect(abs(a.projectedBedtimeMg - 118) < 2)  // 200 × 0,59 à t = 4 h
    #expect(a.bedtimeStatus == .high)
    #expect(a.reason == .bedtime)
    // Seuil de coucher 35 mg : 200 × 1,0285 × e^(−0,13863·t) = 35 (terme d'absorption négligeable)
    // → t = ln(205,7/35)/0,13863 ≈ 12,776 h après 19:00 → ≈ 07:47 le lendemain.
    let expected = TestClock.date(19).addingTimeInterval(12.776 * 3600)
    #expect(abs(a.sleepReadyAt.timeIntervalSince(expected)) < 120)
    #expect(!a.isSleepReady)
}

/// Seuil de coucher 35 mg calé sur Gardiner 2023 (café 107 mg ≥ 8,8 h avant le coucher).
@Test func coffeeAtGardinerCutoffIsElevatedNotHigh() {
    // 107 × 1,0285 × e^(−0,13863 × 8,8) ≈ 32,5 mg → 32,5/35 = 0,93 : élevé, pas haut.
    let bedtime = TestClock.date(23)
    let dose = CaffeineDose(date: bedtime.addingTimeInterval(-8.8 * 3600), milligrams: 107)
    let a = assessor().assess(doses: [dose], at: TestClock.date(15))
    #expect(a.bedtime == bedtime)
    #expect(abs(a.projectedBedtimeMg - 32.5) < 0.2)
    #expect(a.bedtimeStatus == .elevated)
}

@Test func coffeeEightHoursBeforeBedIsHigh() {
    // 107 × 1,0285 × e^(−0,13863 × 8) ≈ 36,3 mg > 35 mg.
    let bedtime = TestClock.date(23)
    let dose = CaffeineDose(date: bedtime.addingTimeInterval(-8 * 3600), milligrams: 107)
    let a = assessor().assess(doses: [dose], at: TestClock.date(16))
    #expect(abs(a.projectedBedtimeMg - 36.3) < 0.2)
    #expect(a.bedtimeStatus == .high)
}

/// Drake 2013 : 400 mg 6 h avant le coucher réduit le sommeil total de plus d'une heure.
@Test func fourHundredMilligramsSixHoursBeforeBedIsHigh() {
    // 400 × 1,0285 × e^(−0,13863 × 6) ≈ 179 mg ≫ 35 mg.
    let bedtime = TestClock.date(23)
    let dose = CaffeineDose(date: bedtime.addingTimeInterval(-6 * 3600), milligrams: 400)
    let a = assessor().assess(doses: [dose], at: TestClock.date(18))
    #expect(abs(a.projectedBedtimeMg - 179) < 1)
    #expect(a.bedtimeStatus == .high)
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

@Test func bedtimeTakesPriorityOverDailyWhenPeakIsNotHigh() {
    // Limite de pic 180,6 mg (M5.6) → peakStatus reste .ok sous 108,4 mg. Les trois 140 mg valent ≈ 83,9 mg à
    // 22:00 ; 35 mg à 21:30 ajoutait ≈ 30,6 mg (114,5 → 0,63, élevé) : on baisse la dernière dose à 20 mg
    // (≈ 17,5 mg → 101,5 mg, ratio 0,56). Coucher : ≈ 89,8 mg projetés à 23:00 ≫ 35 mg ; journée 440 mg ≥ 400.
    let now = TestClock.date(22)
    let doses = [
        CaffeineDose(date: TestClock.date(8), milligrams: 140),
        CaffeineDose(date: TestClock.date(10), milligrams: 140),
        CaffeineDose(date: TestClock.date(12), milligrams: 140),
        CaffeineDose(date: TestClock.date(21, 30), milligrams: 20),
    ]
    let a = assessor().assess(doses: doses, at: now)
    #expect(a.peakStatus == .ok)
    #expect(a.dailyStatus == .high)
    #expect(a.bedtimeStatus == .high)
    #expect(a.reason == .bedtime)
}

@Test func zeroBedtimeLimitDisablesCheckInsteadOfDividingByZero() {
    // Profil construit directement (sans `clamped()`) pour simuler des données corrompues.
    let corrupted = UserProfile(
        halfLifeHours: 5,
        bedtime: ClockTime(hour: 23, minute: 0),
        dailyLimitMg: 400,
        bedtimeLimitMg: 0,
        singleDoseMgPerKg: 3,
        singleDoseCapMg: 200)
    let now = TestClock.date(20)
    let a = LevelAssessor(profile: corrupted, calendar: TestClock.calendar)
        .assess(doses: [CaffeineDose(date: TestClock.date(19), milligrams: 200)], at: now)
    #expect(a.bedtimeStatus == .ok)
    #expect(!a.projectedBedtimeMg.isNaN)
}

@Test func cheapStatusMatchesFullAssessment() {
    let doses = [
        CaffeineDose(date: TestClock.date(8), milligrams: 140),
        CaffeineDose(date: TestClock.date(12), milligrams: 140),
        CaffeineDose(date: TestClock.date(19), milligrams: 200),
        CaffeineDose(date: TestClock.date(day: 11, 9), milligrams: 999),      // futur pour la plupart des instants
    ]
    let instants = [
        TestClock.date(7),                 // avant toute dose
        TestClock.date(8, 30),             // près du pic
        TestClock.date(12, 45),
        TestClock.date(20),                // projection coucher haute
        TestClock.date(23, 30),            // après le coucher
        TestClock.date(day: 11, 3),        // avant 04:00 : journée de la veille
        TestClock.date(day: 11, 10),       // la dose « future » est passée
    ]
    for profileTweak in [{ (_: inout UserProfile) in }, { $0.bedtimeLimitMg = 100 }, { $0.dailyLimitMg = 300 }] {
        let a = assessor(profileTweak)
        for at in instants {
            #expect(a.status(doses: doses, at: at) == a.assess(doses: doses, at: at).status, "\(at)")
        }
        #expect(a.status(doses: [], at: TestClock.date(10)) == .ok)
    }
}

@Test func contextStatusMatchesPerInstantStatusOverTwelveHourScans() {
    let doses = [
        CaffeineDose(date: TestClock.date(9), milligrams: 140),
        CaffeineDose(date: TestClock.date(15), milligrams: 140),
        CaffeineDose(date: TestClock.date(21, 30), milligrams: 80),
    ]
    let starts = [
        TestClock.date(22, 30),            // franchit 23:00 (coucher) puis 04:00 (nouvelle journée)
        TestClock.date(14),                // franchit 23:00 seulement
        TestClock.date(day: 11, 1),        // nuit : coucher déjà passé, puis 04:00
    ]
    for profileTweak in [{ (_: inout UserProfile) in }, { $0.bedtime = ClockTime(hour: 1, minute: 30) }] {
        let a = assessor(profileTweak)
        for start in starts {
            var context = a.dayContext(at: start)
            #expect(context.dayStart <= start && start < context.validUntil)
            var t = start
            let end = start.addingTimeInterval(12 * 3600)
            while t <= end {
                if t >= context.validUntil { context = a.dayContext(at: t) }
                #expect(a.status(doses: doses, at: t, context: context) == a.status(doses: doses, at: t), "\(t)")
                t = t.addingTimeInterval(60)
            }
        }
    }
}

@Test func dayContextBedtimeIsNilOncePassedAndValidUntilIsNextBoundary() {
    let a = assessor()
    let afternoon = a.dayContext(at: TestClock.date(14))
    #expect(afternoon.dayStart == TestClock.date(4))
    #expect(afternoon.bedtime == TestClock.date(23))
    #expect(afternoon.validUntil == TestClock.date(23))
    let night = a.dayContext(at: TestClock.date(23, 30))
    #expect(night.dayStart == TestClock.date(4))
    #expect(night.bedtime == nil)
    #expect(night.validUntil == TestClock.date(day: 11, 4))
    let early = a.dayContext(at: TestClock.date(day: 11, 2))
    #expect(early.dayStart == TestClock.date(4))
    #expect(early.bedtime == nil)
    #expect(early.validUntil == TestClock.date(day: 11, 4))
}

/// `dayContext(at:)` autour d'un changement d'heure (Europe/Paris) : `validUntil` suit le 04:00 à l'horloge,
/// pas un décalage fixe de 24 h.
@Test(arguments: [(3, 28, 23.0), (10, 24, 25.0)])
func dayContextValidUntilFollowsWallClockAcrossDST(month: Int, day: Int, realHours: Double) {
    var paris = Calendar(identifier: .gregorian)
    paris.timeZone = TimeZone(identifier: "Europe/Paris")!
    let a = LevelAssessor(profile: .default, calendar: paris)   // coucher 23:00
    let dayStart = paris.date(from: DateComponents(year: 2026, month: month, day: day, hour: 4))!
    let lateEvening = paris.date(from: DateComponents(year: 2026, month: month, day: day, hour: 23, minute: 30))!
    let context = a.dayContext(at: lateEvening)
    #expect(context.dayStart == dayStart)
    #expect(context.bedtime == nil)   // coucher passé → projection à l'instant
    #expect(context.validUntil == a.day.nextStart(after: lateEvening))
    #expect(context.validUntil.timeIntervalSince(dayStart) == realHours * 3600)
    let comps = paris.dateComponents([.day, .hour], from: context.validUntil)
    #expect(comps.day == day + 1 && comps.hour == 4)
    // Avant le coucher, le contexte expire au coucher (même jour, avant le changement d'heure nocturne).
    let afternoon = paris.date(from: DateComponents(year: 2026, month: month, day: day, hour: 15))!
    let earlier = a.dayContext(at: afternoon)
    #expect(earlier.validUntil == paris.date(from: DateComponents(year: 2026, month: month, day: day, hour: 23)))
}
