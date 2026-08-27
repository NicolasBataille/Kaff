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
