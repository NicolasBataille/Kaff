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

/// Sorties figées avant la révision M4 (contexte calendrier hissé hors du balayage) : elles doivent rester identiques.
@Test func widgetEntryDatesArePinned() {
    let now = TestClock.date(8)
    let noDoses = builder.widgetEntryDates(doses: [], from: now).map { Int($0.timeIntervalSince1970) }
    #expect(noDoses == [1786348800, 1786349700, 1786350600, 1786351500, 1786352400, 1786353300, 1786354200, 1786355100, 1786356000, 1786356900, 1786357800, 1786358700, 1786359600, 1786360500, 1786361400, 1786362300, 1786363200, 1786364100, 1786365000, 1786365900, 1786366800, 1786367700, 1786368600, 1786369500, 1786370400, 1786371300, 1786372200, 1786373100, 1786374000, 1786374900, 1786375800, 1786376700, 1786377600, 1786378500, 1786379400, 1786380300, 1786381200, 1786382100, 1786383000, 1786383900, 1786384800, 1786385700, 1786386600, 1786387500, 1786388400, 1786389300, 1786390200, 1786391100, 1786392000])

    let bigDose = builder.widgetEntryDates(doses: [CaffeineDose(date: now, milligrams: 250)], from: now).map { Int($0.timeIntervalSince1970) }
    #expect(bigDose == [1786348800, 1786349700, 1786350060, 1786350600, 1786351500, 1786352400, 1786353300, 1786354200, 1786355100, 1786355340, 1786356000, 1786356900, 1786357800, 1786358700, 1786359600, 1786360500, 1786361400, 1786362300, 1786363200, 1786364100, 1786365000, 1786365900, 1786366800, 1786367700, 1786368600, 1786369500, 1786370400, 1786371300, 1786372200, 1786373100, 1786374000, 1786374900, 1786375800, 1786376700, 1786377600, 1786378500, 1786379400, 1786380300, 1786381200, 1786382100, 1786383000, 1786383900, 1786384800, 1786385700, 1786386600, 1786387500, 1786388400, 1786389300, 1786390200, 1786391100, 1786391340, 1786392000])

    // 18:00 → 06:00 : franchit le coucher (23:00) puis le début de journée (04:00).
    let evening = TestClock.date(18)
    let bedtimeCrossing = builder.widgetEntryDates(doses: [CaffeineDose(date: TestClock.date(17), milligrams: 120)], from: evening).map { Int($0.timeIntervalSince1970) }
    #expect(bedtimeCrossing == [1786384800, 1786385700, 1786386600, 1786387500, 1786388400, 1786389300, 1786390200, 1786391100, 1786392000, 1786392900, 1786393800, 1786394700, 1786395600, 1786396500, 1786397400, 1786398300, 1786399200, 1786400100, 1786401000, 1786401900, 1786402800, 1786403700, 1786404600, 1786404720, 1786405500, 1786406400, 1786407300, 1786408200, 1786409100, 1786410000, 1786410900, 1786411800, 1786412700, 1786413600, 1786414500, 1786415400, 1786416300, 1786417200, 1786417980, 1786418100, 1786419000, 1786419900, 1786420800, 1786421700, 1786422600, 1786423500, 1786424400, 1786425300, 1786426200, 1786427100, 1786428000])
}
