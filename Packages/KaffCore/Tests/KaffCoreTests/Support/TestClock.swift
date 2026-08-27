import Foundation

/// Calendrier UTC déterministe pour les tests.
enum TestClock {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// 2026-08-`day` à `hour`:`minute` UTC.
    static func date(day: Int = 10, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute))!
    }
}
