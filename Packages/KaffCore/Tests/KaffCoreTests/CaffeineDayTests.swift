import Foundation
import Testing
@testable import KaffCore

private let day = CaffeineDay(calendar: TestClock.calendar)

@Test func dayStartsAtFourInTheMorning() {
    #expect(day.start(containing: TestClock.date(14)) == TestClock.date(4))
    #expect(day.start(containing: TestClock.date(4)) == TestClock.date(4))
    // 01:00 appartient encore à la journée de la veille
    #expect(day.start(containing: TestClock.date(1)) == TestClock.date(day: 9, 4))
}

@Test func bedtimeLaterToday() {
    let bed = ClockTime(hour: 23, minute: 0)
    #expect(day.nextBedtime(bed, after: TestClock.date(20, 15)) == TestClock.date(23))
}

@Test func bedtimeAlreadyPassedIsNow() {
    let bed = ClockTime(hour: 23, minute: 0)
    let lateEvening = TestClock.date(23, 30)
    #expect(day.nextBedtime(bed, after: lateEvening) == lateEvening)
    let lateNight = TestClock.date(day: 11, 1, 0)
    #expect(day.nextBedtime(bed, after: lateNight) == lateNight)
}

@Test func bedtimeAfterMidnightIsTomorrow() {
    let bed = ClockTime(hour: 0, minute: 30)
    #expect(day.nextBedtime(bed, after: TestClock.date(22)) == TestClock.date(day: 11, 0, 30))
}

@Test func bedtimeAcrossSpringForwardStaysOnWallClock() {
    var paris = Calendar(identifier: .gregorian)
    paris.timeZone = TimeZone(identifier: "Europe/Paris")!
    let day = CaffeineDay(calendar: paris)
    // 2026-03-29 : 02:00 → 03:00 à Paris. Coucher 03:30 vu depuis 01:00 = 1 h 30 réelle plus tard, mais 03:30 à l'horloge.
    let now = paris.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 1, minute: 0))!
    let bedtime = day.nextBedtime(ClockTime(hour: 3, minute: 30), after: now)
    let comps = paris.dateComponents([.hour, .minute], from: bedtime)
    #expect(comps.hour == 3 && comps.minute == 30)
    #expect(bedtime.timeIntervalSince(now) == 1.5 * 3600)
}

/// Calendrier Europe/Paris : 2026-03-29 (02:00 → 03:00, journée de 23 h) et 2026-10-25 (03:00 → 02:00, 25 h).
private let paris: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Paris")!
    return c
}()

private func parisDate(month: Int, day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    paris.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}

@Test(arguments: [(3, 28, 23.0), (10, 24, 25.0)])
func nextStartAcrossDSTLandsOnWallClockFourAM(month: Int, day: Int, realHours: Double) {
    let caffeineDay = CaffeineDay(calendar: paris)
    let from = parisDate(month: month, day: day, 4)
    let next = caffeineDay.nextStart(after: from)
    let comps = paris.dateComponents([.month, .day, .hour, .minute], from: next)
    #expect(comps.month == month && comps.day == day + 1 && comps.hour == 4 && comps.minute == 0)
    #expect(next.timeIntervalSince(from) == realHours * 3600)
    // Depuis le soir de la même journée caféine, même 04:00 suivant.
    #expect(caffeineDay.nextStart(after: parisDate(month: month, day: day, 23, 30)) == next)
}
