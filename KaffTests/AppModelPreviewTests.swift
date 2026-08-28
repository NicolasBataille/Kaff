import Foundation
import KaffCore
import Testing
@testable import Kaff_Watch_App

/// `AppModel.preview(adding:at:)`, `peak(afterAdding:)` et `chartPoints(adding:)` : aperçu d'impact pur (brief §3.3).
@MainActor
struct AppModelPreviewTests {
    let health = MockHealthStore()
    let widgets = SpyWidgetReloader()
    let defaults: UserDefaults
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    init() {
        let name = "kaff.previewtests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
    }

    func makeModel() -> AppModel {
        AppModel(health: health, profileStore: ProfileStore(defaults: defaults),
                 cacheStore: CacheStore(defaults: defaults), widgets: widgets,
                 now: { now }, authorizationRetryDelay: .zero)
    }

    @Test func previewRaisesLevelAtPeakByAboutNinetyPercentOfDose() async {
        health.stored = [CaffeineDose(date: now.addingTimeInterval(-3600), milligrams: 63)]
        let model = makeModel()
        await model.start()
        let peak = now.addingTimeInterval(model.assessor.model.timeToPeakHours * 3600)
        let delta = model.preview(adding: 100, at: peak).currentMg - model.assessment(at: peak).currentMg
        #expect(abs(delta - 90) < 2)
    }

    @Test func previewDefaultsToNowAndDoesNotMutateState() async throws {
        health.stored = [CaffeineDose(date: now.addingTimeInterval(-3600), milligrams: 63)]
        let model = makeModel()
        await model.start()
        let dosesBefore = model.doses
        let reloadsBefore = widgets.reloadCount
        let cacheBefore = try #require(CacheStore(defaults: defaults).read())
        let preview = model.preview(adding: 100)
        #expect(preview.now == now)
        #expect(preview.currentMg == model.assessment().currentMg)  // dose à `now` : encore rien d'absorbé
        #expect(model.doses == dosesBefore)
        #expect(widgets.reloadCount == reloadsBefore)
        #expect(CacheStore(defaults: defaults).read() == cacheBefore)
        #expect(health.savedIDs.isEmpty)
    }

    @Test func previewCountsHypotheticalDoseInDailyTotal() async {
        let model = makeModel()
        await model.start()
        #expect(model.preview(adding: 100).dailyTotalMg == model.assessment().dailyTotalMg + 100)
    }

    @Test func peakAfterAddingIsNearFortyFourMinutesWithoutOtherDoses() async {
        let model = makeModel()
        await model.start()
        let peak = model.peak(afterAdding: 100)
        #expect(abs(peak.date.timeIntervalSince(now) - 44 * 60) <= 10 * 60)
        #expect(abs(peak.mg - 90) < 3)
    }

    @Test func chartPointsWithHypotheticalDoseNeverBelowBaseline() async {
        health.stored = [CaffeineDose(date: now.addingTimeInterval(-7200), milligrams: 95)]
        let model = makeModel()
        await model.start()
        let before = model.chartPoints(from: now, hours: 6, stepMinutes: 10)
        let after = model.chartPoints(from: now, hours: 6, stepMinutes: 10, adding: 100)
        #expect(before.count == after.count)
        #expect(zip(before, after).allSatisfy { $0.milligrams <= $1.milligrams + 1e-9 })
        #expect(after.last!.milligrams > before.last!.milligrams)
    }
}
