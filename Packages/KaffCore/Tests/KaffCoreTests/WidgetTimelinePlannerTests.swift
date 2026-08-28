import Foundation
import Testing
@testable import KaffCore

@Test func noSnapshotGivesSingleEmptyEntry() {
    let now = TestClock.date(8)
    let entries = WidgetTimelinePlanner.entries(snapshot: nil, now: now, calendar: TestClock.calendar)
    #expect(entries.count == 1)
    #expect(entries[0].date == now && entries[0].hasData == false && entries[0].milligrams == 0)
    #expect(entries[0].sparkline.allSatisfy { $0 == 0 })
}

@Test func snapshotGivesGridAndTransitions() {
    let now = TestClock.date(8)
    let snapshot = CacheSnapshot(doses: [CaffeineDose(date: now, milligrams: 250)], limits: AssessmentLimits(profile: .default), updatedAt: now)
    let entries = WidgetTimelinePlanner.entries(snapshot: snapshot, now: now, calendar: TestClock.calendar)
    #expect(entries.count > 49)
    #expect(entries.first?.date == now)
    #expect(entries.allSatisfy { $0.hasData && $0.limitMg == 200 })
    let peak = entries.max { $0.milligrams < $1.milligrams }!
    #expect(peak.status == .high)
    #expect(entries.last!.milligrams < peak.milligrams)
}

@Test func sparklineStartsAtEntryAndFollowsTheCurve() {
    let now = TestClock.date(8)
    let doses = [CaffeineDose(date: now, milligrams: 250)]
    let snapshot = CacheSnapshot(doses: doses, limits: AssessmentLimits(profile: .default), updatedAt: now)
    let entries = WidgetTimelinePlanner.entries(snapshot: snapshot, now: now, calendar: TestClock.calendar)
    #expect(entries.allSatisfy { $0.sparkline.count == WidgetTimelinePlanner.sparklineSamples })
    // Premier échantillon = niveau de l'entrée ; les suivants suivent le modèle PK pas à pas.
    let model = PharmacokineticModel(halfLifeHours: UserProfile.default.halfLifeHours)
    for entry in entries {
        #expect(entry.sparkline[0] == entry.milligrams)
        let step = Double(WidgetTimelinePlanner.sparklineStepMinutes * 60)
        let expected = model.amount(doses: doses, at: entry.date.addingTimeInterval(step * 5))
        #expect(abs(entry.sparkline[5] - expected) < 0.001)
    }
    // Loin après le pic, la sparkline est strictement décroissante.
    let last = entries.last!.sparkline
    #expect(zip(last, last.dropFirst()).allSatisfy { $0 > $1 })
}

@Test func firstEntryEqualsFirstOfEntries() {
    let now = TestClock.date(8)
    let doses = [CaffeineDose(date: TestClock.date(7), milligrams: 120), CaffeineDose(date: now, milligrams: 250)]
    let snapshot = CacheSnapshot(doses: doses, limits: AssessmentLimits(profile: .default), updatedAt: now)
    let first = WidgetTimelinePlanner.firstEntry(snapshot: snapshot, now: now, calendar: TestClock.calendar)
    #expect(first == WidgetTimelinePlanner.entries(snapshot: snapshot, now: now, calendar: TestClock.calendar).first)
    #expect(first.hasData && first.date == now && first.sparkline.count == WidgetTimelinePlanner.sparklineSamples)
    let empty = WidgetTimelinePlanner.firstEntry(snapshot: nil, now: now, calendar: TestClock.calendar)
    #expect(empty == WidgetTimelinePlanner.entries(snapshot: nil, now: now, calendar: TestClock.calendar).first)
    #expect(empty == .empty(at: now))
}
