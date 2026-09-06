import Foundation
import Testing
@testable import KaffCore

private let calendar = TestClock.calendar
/// Milieu de journée : aucune session de nuit ne chevauche `now`.
private let now = TestClock.date(day: 24, 12)

/// Session commençant le `day` à `hour`:`minute` et durant `hours` heures.
private func session(day: Int, _ hour: Int, _ minute: Int = 0, hours: Double = 7, kind: SleepSession.Kind = .asleep) -> SleepSession {
    let start = TestClock.date(day: day, hour, minute)
    return SleepSession(start: start, end: start.addingTimeInterval(hours * 3600), kind: kind)
}

private func estimate(_ sessions: [SleepSession]) -> BedtimeEstimate? {
    BedtimeInference.estimate(sessions: sessions, now: now, calendar: calendar)
}

@Test func circularMedianAcrossMidnight() {
    // 23:30, 00:00 (nuit du 21) et 00:30 (nuit du 22) : médiane 00:00, pas 12:00.
    let result = estimate([session(day: 20, 23, 30), session(day: 22, 0, 0), session(day: 23, 0, 30)])
    #expect(result == BedtimeEstimate(time: ClockTime(hour: 0, minute: 0), nights: 3))
}

@Test func fewerThanThreeNightsGivesNil() {
    #expect(estimate([session(day: 21, 23), session(day: 22, 23)]) == nil)
    #expect(estimate([]) == nil)
}

@Test func shortAfternoonNapIsIgnored() {
    // La sieste du 21 tombe dans la journée caféine de la nuit 23:00 : elle ne doit pas en devenir le début.
    let nights = [session(day: 20, 23), session(day: 21, 23), session(day: 22, 23)]
    let nap = session(day: 21, 14, hours: 1.5)
    #expect(estimate(nights + [nap]) == BedtimeEstimate(time: ClockTime(hour: 23, minute: 0), nights: 3))
    // Sieste sur un jour sans nuit : ne crée pas de nuit supplémentaire.
    let lonelyNap = session(day: 18, 14, hours: 1.5)
    #expect(estimate(nights + [lonelyNap]) == BedtimeEstimate(time: ClockTime(hour: 23, minute: 0), nights: 3))
}

@Test func longAfternoonSleepCounts() {
    // 13:00–17:00 (4 h > 3 h) compte comme une nuit ; médiane paire de 23:00/23:00 → 23:00.
    let nights = [session(day: 20, 23), session(day: 21, 23), session(day: 22, 23)]
    let longSleep = session(day: 18, 13, hours: 4)
    #expect(estimate(nights + [longSleep]) == BedtimeEstimate(time: ClockTime(hour: 23, minute: 0), nights: 4))
}

@Test func lookbackWindowIsFourteenDays() {
    // now = 24 à 12:00 → fenêtre à partir du 10 à 12:00 : le 9 est exclu, le 11 inclus.
    let recent = [session(day: 21, 23), session(day: 22, 23), session(day: 23, 23)]
    let tooOld = session(day: 9, 23)
    #expect(estimate(recent + [tooOld])?.nights == 3)
    let oldEnough = session(day: 11, 23)
    #expect(estimate(recent + [oldEnough])?.nights == 4)
}

@Test func earliestStartOfTheNightWhateverTheKind() {
    let nights = [
        session(day: 20, 23, 10, kind: .inBed), session(day: 20, 23, 25, kind: .asleep),
        session(day: 21, 23, 10, kind: .inBed), session(day: 21, 23, 25, kind: .asleep),
        session(day: 22, 23, 10, kind: .inBed), session(day: 22, 23, 25, kind: .asleep),
    ]
    #expect(estimate(nights) == BedtimeEstimate(time: ClockTime(hour: 23, minute: 10), nights: 3))
}

@Test func subSecondTimestampsStayInTheSameNight() {
    // Santé horodate à la sous-seconde : deux sessions à 0,5 s d'écart restent une seule nuit.
    let nights = [session(day: 20, 23), session(day: 21, 23), session(day: 22, 23)]
    let base = session(day: 22, 23, 15)
    let jittered = SleepSession(start: base.start.addingTimeInterval(0.5), end: base.end, kind: .inBed)
    #expect(estimate(nights + [jittered]) == BedtimeEstimate(time: ClockTime(hour: 23, minute: 0), nights: 3))
}

@Test func resultIsRoundedToFiveMinutes() {
    let down = [session(day: 20, 23, 1), session(day: 21, 23, 2), session(day: 22, 23, 4)]
    #expect(estimate(down)?.time == ClockTime(hour: 23, minute: 0))
    let up = [session(day: 20, 23, 1), session(day: 21, 23, 3), session(day: 22, 23, 4)]
    #expect(estimate(up)?.time == ClockTime(hour: 23, minute: 5))
}

@Test func daytimeResultIsRejected() {
    // 05:00–13:00 (8 h) n'est pas une sieste : la médiane 05:00 tombe dans la journée caféine suivante → nil.
    let mornings = [session(day: 20, 5, hours: 8), session(day: 21, 5, hours: 8), session(day: 22, 5, hours: 8)]
    #expect(estimate(mornings) == nil)
}

@Test func inputOrderDoesNotMatter() {
    let sessions = [
        session(day: 20, 23, 30), session(day: 21, 22, 45, kind: .inBed), session(day: 21, 23, 0),
        session(day: 23, 0, 15), session(day: 22, 14, hours: 1),
    ]
    let expected = estimate(sessions)
    #expect(expected != nil)
    #expect(estimate(sessions.reversed()) == expected)
    #expect(estimate(sessions.shuffled()) == expected)
}

@Test func sessionAfterNowIsIgnored() {
    let nights = [session(day: 20, 23), session(day: 21, 23), session(day: 22, 23)]
    let future = session(day: 24, 22)
    #expect(estimate(nights + [future]) == BedtimeEstimate(time: ClockTime(hour: 23, minute: 0), nights: 3))
}

/// Revue M6.7 : HealthKit écrit une nuit en plusieurs échantillons (phases, réveils). Un fragment qui commence
/// après 04:00 tombe dans la journée caféine suivante et en deviendrait le « coucher » (04:15 au lieu de 23:00).
/// Les fragments d'une même nuit (écart ≤ `mergeGapHours`) sont fusionnés avant le regroupement.
@Test func fragmentedNightsAcrossFourAmAreMergedIntoOneNight() {
    var sessions: [SleepSession] = []
    for day in 20...22 {
        sessions += [
            session(day: day, 23, 0, hours: 1.5, kind: .asleep),          // 23:00–00:30
            session(day: day + 1, 0, 40, hours: 3.5, kind: .asleep),       // 00:40–04:10 (réveil de 10 min)
            session(day: day + 1, 4, 15, hours: 2.75, kind: .asleep),      // 04:15–07:00 : après 04:00
        ]
    }
    #expect(estimate(sessions) == BedtimeEstimate(time: ClockTime(hour: 23, minute: 0), nights: 3))
}

/// Un fragment de plus de 3 h qui commence après 05:00 (longue phase profonde tardive) reste rattaché à sa nuit.
@Test func lateLongFragmentStaysWithItsNight() {
    let sessions = (20...22).flatMap { day in
        [session(day: day, 22, 30, hours: 6.5), session(day: day + 1, 5, 10, hours: 3.5)]   // 22:30–05:00, 05:10–08:40
    }
    #expect(estimate(sessions) == BedtimeEstimate(time: ClockTime(hour: 22, minute: 30), nights: 3))
}

/// Deux nuits consécutives ne fusionnent jamais (écart ≈ 16 h), et une sieste isolée non plus.
@Test func mergingNeverJoinsDistinctNights() {
    let sessions = [session(day: 20, 23), session(day: 21, 23), session(day: 22, 23), session(day: 22, 14, hours: 1)]
    #expect(estimate(sessions) == BedtimeEstimate(time: ClockTime(hour: 23, minute: 0), nights: 3))
}
