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

/// v1 (profil brut) et v2 (`singleDoseLimitMg`) ne sont jamais relus ; ils sont purgés à la première écriture.
@Test func legacyV1AndV2SnapshotsAreIgnoredAndRemovedOnWrite() throws {
    let defaults = freshDefaults()
    let legacyKeys = ["cache.snapshot.v1", "cache.snapshot.v2"]
    defaults.set(Data("{\"profile\":{}}".utf8), forKey: legacyKeys[0])
    defaults.set(Data("{\"limits\":{\"singleDoseLimitMg\":200}}".utf8), forKey: legacyKeys[1])
    let store = CacheStore(defaults: defaults)
    #expect(CacheStore.key == "cache.snapshot.v3")
    #expect(store.read() == nil)
    try store.write(CacheSnapshot(doses: [], limits: AssessmentLimits(profile: .default), updatedAt: TestClock.date(10)))
    for key in legacyKeys {
        #expect(defaults.data(forKey: key) == nil, "clé \(key)")
    }
    #expect(store.read() != nil)
}
