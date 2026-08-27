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
