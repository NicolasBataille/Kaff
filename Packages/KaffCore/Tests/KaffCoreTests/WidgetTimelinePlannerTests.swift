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
    // La limite affichée par l'anneau est la limite de pic (charge corporelle), 200 × 0,903 ≈ 180,6 mg (M5.6).
    #expect(entries.allSatisfy { $0.hasData && $0.limitMg == UserProfile.default.peakLimitMg })
    #expect(abs(entries[0].limitMg - 180.6) < 0.1)
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

// MARK: Obsolescence (M6.6)

/// Snapshot écrit il y a 29 h avec une fenêtre de 30 h : l'entrée à `now` n'est pas obsolète, celle à +2 h l'est
/// (la timeline est précalculée : chaque entrée évalue l'obsolescence à sa propre date).
@Test func stalenessIsEvaluatedPerEntryDate() {
    let now = TestClock.date(8)
    let doses = [CaffeineDose(date: TestClock.date(7), milligrams: 120)]
    let snapshot = CacheSnapshot(doses: doses, limits: AssessmentLimits(profile: .default),
                                 updatedAt: now.addingTimeInterval(-29 * 3600), windowHours: 30)
    let entries = WidgetTimelinePlanner.entries(snapshot: snapshot, now: now, calendar: TestClock.calendar)
    #expect(entries.first?.isStale == false)
    let twoHoursLater = entries.first { $0.date == now.addingTimeInterval(2 * 3600) }
    #expect(twoHoursLater?.isStale == true)
    // Strictement au-delà de la fenêtre : l'entrée à +1 h (exactement 30 h) n'est pas encore obsolète.
    #expect(entries.first { $0.date == now.addingTimeInterval(3600) }?.isStale == false)
    #expect(entries.allSatisfy { $0.isStale == ($0.date > now.addingTimeInterval(3600)) })
}

@Test func freshSnapshotIsNeverStaleOverTheHorizon() {
    let now = TestClock.date(8)
    let snapshot = CacheSnapshot(doses: [CaffeineDose(date: now, milligrams: 250)],
                                 limits: AssessmentLimits(profile: .default), updatedAt: now)
    let entries = WidgetTimelinePlanner.entries(snapshot: snapshot, now: now, calendar: TestClock.calendar)
    #expect(entries.last!.date >= now.addingTimeInterval(12 * 3600))
    #expect(entries.allSatisfy { !$0.isStale })
}

@Test func emptyEntryIsNotStale() {
    let now = TestClock.date(8)
    #expect(WidgetEntryData.empty(at: now).isStale == false)
    #expect(WidgetTimelinePlanner.entries(snapshot: nil, now: now, calendar: TestClock.calendar).first?.isStale == false)
}

@Test func firstEntryStalenessMatchesEntries() {
    let now = TestClock.date(8)
    let doses = [CaffeineDose(date: TestClock.date(7), milligrams: 120)]
    let stale = CacheSnapshot(doses: doses, limits: AssessmentLimits(profile: .default),
                              updatedAt: now.addingTimeInterval(-31 * 3600), windowHours: 30)
    let first = WidgetTimelinePlanner.firstEntry(snapshot: stale, now: now, calendar: TestClock.calendar)
    #expect(first.isStale)
    #expect(first == WidgetTimelinePlanner.entries(snapshot: stale, now: now, calendar: TestClock.calendar).first)
    // Une fenêtre plus large (t½ = 8 h → 80 h) lève l'obsolescence pour le même `updatedAt`.
    let wide = CacheSnapshot(doses: doses, limits: AssessmentLimits(profile: .default),
                             updatedAt: now.addingTimeInterval(-31 * 3600), windowHours: 80)
    #expect(WidgetTimelinePlanner.firstEntry(snapshot: wide, now: now, calendar: TestClock.calendar).isStale == false)
}

// MARK: Concentration et unité (M7.2, spec §5.3 et §8)

private func snapshotForUnit(_ unit: DisplayUnit, doses: [CaffeineDose], now: Date) -> CacheSnapshot {
    var profile = UserProfile.default
    profile.manualWeightKg = 60   // 40 L
    profile.complicationUnit = unit
    return CacheSnapshot(doses: doses, limits: AssessmentLimits(profile: profile), updatedAt: now)
}

/// Chaque entrée porte `milligrams / distributionLitres` (non arrondi : la mise en forme à une décimale est celle du
/// widget) et l'unité du snapshot.
@Test func entriesCarryConcentrationAndUnitFromTheSnapshot() {
    let now = TestClock.date(8)
    let doses = [CaffeineDose(date: TestClock.date(7), milligrams: 120), CaffeineDose(date: now, milligrams: 250)]
    let snapshot = snapshotForUnit(.milligramsPerLitre, doses: doses, now: now)
    #expect(snapshot.limits.distributionLitres == 40)
    let entries = WidgetTimelinePlanner.entries(snapshot: snapshot, now: now, calendar: TestClock.calendar)
    #expect(entries.allSatisfy { $0.unit == .milligramsPerLitre })
    #expect(entries.allSatisfy { $0.milligramsPerLitre == $0.milligrams / snapshot.limits.distributionLitres })
    // Pic ≈ (250 × 0,903 + reste des 120 ≈ 97) / 40 ≈ 8,1 mg/L, jamais nul sur l'horizon.
    let peak = entries.max { $0.milligramsPerLitre < $1.milligramsPerLitre }!
    #expect(abs(peak.milligramsPerLitre - 8.1) < 0.2)
    #expect(entries.allSatisfy { $0.milligramsPerLitre > 0 })
    let first = WidgetTimelinePlanner.firstEntry(snapshot: snapshot, now: now, calendar: TestClock.calendar)
    #expect(first == entries.first)
    #expect(first.unit == .milligramsPerLitre && first.milligramsPerLitre == first.milligrams / 40)
}

/// L'anneau ne change jamais avec l'unité (spec §5.3) : même snapshot en mg et en mg/L → mêmes `milligrams`,
/// `limitMg`, `status`, `sparkline`, donc même `milligrams / limitMg` (le `ringProgress` du widget).
@Test func ringIsIndependentOfTheDisplayUnit() {
    let now = TestClock.date(8)
    let doses = [CaffeineDose(date: TestClock.date(7), milligrams: 120), CaffeineDose(date: now, milligrams: 250)]
    let inMg = WidgetTimelinePlanner.entries(snapshot: snapshotForUnit(.milligrams, doses: doses, now: now),
                                             now: now, calendar: TestClock.calendar)
    let inMgPerL = WidgetTimelinePlanner.entries(snapshot: snapshotForUnit(.milligramsPerLitre, doses: doses, now: now),
                                                 now: now, calendar: TestClock.calendar)
    // Grille 15 min sur 12 h = 49 points, plus les transitions (identiques dans les deux unités).
    #expect(inMg.count == inMgPerL.count && inMg.count >= 49)
    for (a, b) in zip(inMg, inMgPerL) {
        #expect(a.date == b.date)
        #expect(a.milligrams == b.milligrams)
        #expect(a.limitMg == b.limitMg)
        #expect(a.status == b.status)
        #expect(a.sparkline == b.sparkline)
        #expect(a.sleepReadyAt == b.sleepReadyAt && a.isSleepReady == b.isSleepReady && a.isStale == b.isStale)
        #expect(a.milligrams / a.limitMg == b.milligrams / b.limitMg)
        #expect(a.milligramsPerLitre == b.milligramsPerLitre)
        #expect(a.unit == .milligrams && b.unit == .milligramsPerLitre)
    }
}

@Test func emptyEntryHasNoConcentrationAndMilligramsUnit() {
    let now = TestClock.date(8)
    let empty = WidgetEntryData.empty(at: now)
    #expect(empty.milligramsPerLitre == 0)
    #expect(empty.unit == .milligrams)
    let noSnapshot = WidgetTimelinePlanner.entries(snapshot: nil, now: now, calendar: TestClock.calendar)
    #expect(noSnapshot.first?.milligramsPerLitre == 0 && noSnapshot.first?.unit == .milligrams)
}

/// Identité algébrique de la spec §5.3 : C / C_limite = A / A_limite, le même volume divisant les deux membres.
@Test func concentrationRatioEqualsMilligramRatio() {
    let now = TestClock.date(8)
    let doses = [CaffeineDose(date: TestClock.date(7), milligrams: 120), CaffeineDose(date: now, milligrams: 250)]
    let snapshot = snapshotForUnit(.milligramsPerLitre, doses: doses, now: now)
    let entries = WidgetTimelinePlanner.entries(snapshot: snapshot, now: now, calendar: TestClock.calendar)
    for e in entries where e.milligrams > 0 {
        let concentrationRatio = e.milligramsPerLitre / snapshot.limits.peakLimitMgPerLitre
        #expect(abs(concentrationRatio - e.milligrams / e.limitMg) < 1e-9)
    }
}

