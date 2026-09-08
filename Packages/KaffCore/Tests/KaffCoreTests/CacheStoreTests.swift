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

/// M6.6 : `windowHours` s'ajoute à la v3 sans changer de clé ; un blob v3 antérieur (sans la clé) se relit avec 30 h.
@Test func v3BlobWithoutWindowHoursDecodesWithDefaultWindow() throws {
    let defaults = freshDefaults()
    let snapshot = CacheSnapshot(
        doses: [CaffeineDose(date: TestClock.date(9), milligrams: 63)],
        limits: AssessmentLimits(profile: .default), updatedAt: TestClock.date(10), windowHours: 50)
    var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
    #expect(json.removeValue(forKey: "windowHours") != nil)
    defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: CacheStore.key)
    let read = try #require(CacheStore(defaults: defaults).read())
    #expect(read.windowHours == 30)
    #expect(CacheSnapshot.defaultWindowHours == 30)
    #expect(read.doses == snapshot.doses && read.limits == snapshot.limits && read.updatedAt == snapshot.updatedAt)
}

/// Revue sécurité M6.7 : un blob altéré (fenêtre négative, nulle ou NaN) retombe sur la fenêtre par défaut
/// plutôt que de rendre la complication toujours (ou jamais) obsolète.
@Test(arguments: [-1.0, 0.0, Double.nan, Double.infinity])
func invalidWindowHoursFallsBackToDefault(bad: Double) throws {
    let defaults = freshDefaults()
    let snapshot = CacheSnapshot(doses: [], limits: AssessmentLimits(profile: .default), updatedAt: TestClock.date(10))
    var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
    // JSON n'encode ni NaN ni l'infini : on les injecte comme chaînes que le décodeur JSON de Foundation refuse
    // (retour nil, comme un blob corrompu) — seuls les nombres finis passent par le repli.
    json["windowHours"] = bad.isFinite ? bad : "\(bad)"
    defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: CacheStore.key)
    let read = CacheStore(defaults: defaults).read()
    #expect(read == nil || read?.windowHours == CacheSnapshot.defaultWindowHours)
    if bad.isFinite { #expect(read?.windowHours == CacheSnapshot.defaultWindowHours) }
}

@Test func windowHoursRoundTrips() throws {
    let store = CacheStore(defaults: freshDefaults())
    let snapshot = CacheSnapshot(doses: [], limits: AssessmentLimits(profile: .default),
                                 updatedAt: TestClock.date(10), windowHours: 50)
    try store.write(snapshot)
    #expect(store.read() == snapshot)
    #expect(store.read()?.windowHours == 50)
}

// MARK: - Volume de distribution et unité (M7.1)

/// M7.1 : `distributionLitres` et `complicationUnit` s'ajoutent aux `limits` de la v3 sans changer de clé ; un blob v3
/// antérieur se relit avec 47,0 L (repli 70 kg) et l'unité mg.
@Test func v3BlobWithoutVolumeAndUnitDecodesWithDefaults() throws {
    let defaults = freshDefaults()
    var profile = UserProfile.default
    profile.manualWeightKg = 60
    profile.complicationUnit = .milligramsPerLitre
    let snapshot = CacheSnapshot(doses: [CaffeineDose(date: TestClock.date(9), milligrams: 63)],
                                 limits: AssessmentLimits(profile: profile), updatedAt: TestClock.date(10))
    var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
    var limits = try #require(json["limits"] as? [String: Any])
    #expect(limits.removeValue(forKey: "distributionLitres") != nil)
    #expect(limits.removeValue(forKey: "complicationUnit") != nil)
    json["limits"] = limits
    defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: CacheStore.key)
    let read = try #require(CacheStore(defaults: defaults).read())
    #expect(read.limits.distributionLitres == 47.0)
    #expect(read.limits.complicationUnit == .milligrams)
    #expect(read.limits.peakLimitMg == snapshot.limits.peakLimitMg)
    #expect(read.limits.bedtime == snapshot.limits.bedtime)
    #expect(read.doses == snapshot.doses && read.updatedAt == snapshot.updatedAt)
}

/// Blob altéré (volume nul, négatif ou non fini) : repli sur 47,0 L plutôt qu'une division par zéro dans le widget.
@Test(arguments: [-1.0, 0.0, Double.nan, Double.infinity])
func invalidDistributionLitresFallsBackToDefault(bad: Double) throws {
    let defaults = freshDefaults()
    let snapshot = CacheSnapshot(doses: [], limits: AssessmentLimits(profile: .default), updatedAt: TestClock.date(10))
    var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
    var limits = try #require(json["limits"] as? [String: Any])
    // Même convention que `invalidWindowHoursFallsBackToDefault` : NaN/∞ injectés comme chaînes, refusés par le décodeur.
    limits["distributionLitres"] = bad.isFinite ? bad : "\(bad)"
    json["limits"] = limits
    defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: CacheStore.key)
    let read = CacheStore(defaults: defaults).read()
    #expect(read == nil || read?.limits.distributionLitres == 47.0)
    if bad.isFinite { #expect(read?.limits.distributionLitres == 47.0) }
}

@Test func volumeAndUnitRoundTripThroughTheCache() throws {
    let store = CacheStore(defaults: freshDefaults())
    var profile = UserProfile.default
    profile.manualWeightKg = 72
    profile.complicationUnit = .milligramsPerLitre
    let snapshot = CacheSnapshot(doses: [], limits: AssessmentLimits(profile: profile), updatedAt: TestClock.date(10))
    try store.write(snapshot)
    let read = try #require(store.read())
    #expect(read == snapshot)
    #expect(read.limits.distributionLitres == 48.0)
    #expect(read.limits.complicationUnit == .milligramsPerLitre)
}
