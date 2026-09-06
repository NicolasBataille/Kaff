import Foundation
import KaffCore
import Testing
@testable import Kaff_Watch_App

/// `AppModel.historySections(days:)` : regroupement par journée caféine (04:00 → 04:00), pur (brief §3.5).
@MainActor
struct AppModelHistoryTests {
    let health = MockHealthStore()
    let widgets = SpyWidgetReloader()
    let notifications = MockNotificationScheduler()
    let defaults: UserDefaults
    let calendar: Calendar
    /// 2026-08-28 12:00, Europe/Paris.
    let now: Date

    init() {
        let name = "kaff.historytests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        self.calendar = calendar
        now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 12))!
    }

    func makeModel() -> AppModel {
        AppModel(health: health, profileStore: ProfileStore(defaults: defaults),
                 cacheStore: CacheStore(defaults: defaults), widgets: widgets, notifications: notifications,
                 calendar: calendar, now: { now }, authorizationRetryDelay: .zero)
    }

    /// 2026-08-`day` à `hour`:`minute`, Europe/Paris.
    func date(day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute))!
    }

    func dose(day: Int, _ hour: Int, _ minute: Int = 0, mg: Double = 63) -> CaffeineDose {
        CaffeineDose(date: date(day: day, hour, minute), milligrams: mg)
    }

    @Test func doseBeforeFourAMBelongsToPreviousCaffeineDay() async {
        let night = dose(day: 28, 0, 9)
        let morning = dose(day: 28, 9)
        health.stored = [night, morning]
        let model = makeModel()
        await model.start()
        let sections = model.historySections()
        #expect(sections.map(\.dayStart) == [date(day: 28, 4), date(day: 27, 4)])
        #expect(sections[0].doses == [morning])
        #expect(sections[1].doses == [night])
    }

    @Test func sectionsAndDosesAreNewestFirst() async {
        let early = dose(day: 26, 8)
        let late = dose(day: 26, 20)
        let today = dose(day: 28, 9)
        health.stored = [early, today, late]
        let model = makeModel()
        await model.start()
        let sections = model.historySections()
        #expect(sections.map(\.dayStart) == [date(day: 28, 4), date(day: 26, 4)])
        #expect(sections[1].doses == [late, early])
        #expect(sections.map(\.id) == sections.map(\.dayStart))
    }

    @Test func windowCoversSevenCaffeineDaysIncludingToday() async {
        let eightDaysAgo = dose(day: 20, 9)
        let justBeforeWindow = dose(day: 22, 3, 59)
        let firstOfWindow = dose(day: 22, 4)
        health.stored = [eightDaysAgo, justBeforeWindow, firstOfWindow]
        let model = makeModel()
        await model.start()
        let sections = model.historySections(days: 7)
        #expect(sections.map(\.dayStart) == [date(day: 22, 4)])
        #expect(sections[0].doses == [firstOfWindow])
    }

    @Test func noDosesYieldsNoSections() async {
        let model = makeModel()
        await model.start()
        #expect(model.historySections().isEmpty)
    }
}
