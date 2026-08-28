import Foundation
import Testing
@testable import KaffCore

private func freshDefaults() -> UserDefaults {
    let name = "kaff.tests.\(UUID().uuidString)"
    let d = UserDefaults(suiteName: name)!
    d.removePersistentDomain(forName: name)
    return d
}

@Test func cacheRoundTrip() throws {
    let store = CacheStore(defaults: freshDefaults())
    #expect(store.read() == nil)
    let snapshot = CacheSnapshot(
        doses: [CaffeineDose(date: TestClock.date(9), milligrams: 63, drinkID: "espresso", volumeML: 30)],
        limits: AssessmentLimits(profile: .default),
        updatedAt: TestClock.date(10))
    try store.write(snapshot)
    #expect(store.read() == snapshot)
    store.clear()
    #expect(store.read() == nil)
}

@Test func corruptedCacheReadsAsNil() {
    let defaults = freshDefaults()
    defaults.set(Data("garbage".utf8), forKey: CacheStore.key)
    #expect(CacheStore(defaults: defaults).read() == nil)
}

@Test func legacyV1SnapshotIsIgnoredAndRemovedOnWrite() throws {
    let defaults = freshDefaults()
    let legacyKey = "cache.snapshot.v1"
    defaults.set(Data("{\"profile\":{}}".utf8), forKey: legacyKey)
    let store = CacheStore(defaults: defaults)
    #expect(CacheStore.key == "cache.snapshot.v2")
    #expect(store.read() == nil)
    try store.write(CacheSnapshot(doses: [], limits: AssessmentLimits(profile: .default), updatedAt: TestClock.date(10)))
    #expect(defaults.data(forKey: legacyKey) == nil)
    #expect(store.read() != nil)
}
