import Foundation
import Testing
@testable import KaffCore

private let builder = TimelineBuilder(assessor: LevelAssessor(profile: .default, calendar: TestClock.calendar))

@Test func chartPointsCoverRangeWithStep() {
    let start = TestClock.date(8)
    let points = builder.chartPoints(doses: [], from: start, hours: 2, stepMinutes: 30)
    #expect(points.count == 5)
    #expect(points.first?.date == start)
    #expect(points.last?.date == start.addingTimeInterval(2 * 3600))
    #expect(points.allSatisfy { $0.milligrams == 0 && $0.status == .ok })
}

@Test func widgetGridWithoutDosesIsEvery15Minutes() {
    let now = TestClock.date(8)
    let dates = builder.widgetEntryDates(doses: [], from: now)
    #expect(dates.count == 49)
    #expect(dates.first == now)
    #expect(dates.last == now.addingTimeInterval(12 * 3600))
}

@Test func widgetEntriesIncludeStatusTransitions() {
    let now = TestClock.date(8)
    let doses = [CaffeineDose(date: now, milligrams: 250)]
    let dates = builder.widgetEntryDates(doses: doses, from: now)
    let grid = Set(builder.widgetEntryDates(doses: [], from: now))
    let extras = dates.filter { !grid.contains($0) }
    #expect(!extras.isEmpty)
    #expect(dates == dates.sorted() && Set(dates).count == dates.count)
    let assessor = builder.assessor
    for d in extras {
        let before = assessor.assess(doses: doses, at: d.addingTimeInterval(-60))
        let after = assessor.assess(doses: doses, at: d)
        let changed = before.status != after.status || before.isSleepReady != after.isSleepReady
        #expect(changed, "entrée \(d) sans transition")
    }
}
