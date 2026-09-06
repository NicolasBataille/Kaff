import Foundation
import Testing
@testable import KaffCore

@Test func drinkScalesMilligramsLinearly() {
    let espresso = Drink(id: "espresso", name: "Espresso", milligrams: 63, volumeML: 30, symbol: "cup.and.saucer.fill")
    #expect(espresso.milligrams(forVolumeML: 60) == 126)
    #expect(espresso.milligrams(forVolumeML: 0) == 0)
}

@Test func weightPrefersManualThenHealthKitThenFallback() {
    var p = UserProfile.default
    #expect(p.weightKg == UserProfile.fallbackWeightKg && p.isWeightEstimated)
    p.healthKitWeightKg = 80
    #expect(p.weightKg == 80 && !p.isWeightEstimated)
    p.manualWeightKg = 75
    #expect(p.weightKg == 75)
}

@Test func singleDoseLimitIsCappedAt200() {
    var p = UserProfile.default
    p.manualWeightKg = 60
    #expect(p.singleDoseLimitMg == 180)
    p.manualWeightKg = 90
    #expect(p.singleDoseLimitMg == 200)
}

@Test func profileClampsOutOfRangeValues() {
    var p = UserProfile.default
    p.manualWeightKg = 10
    p.healthKitWeightKg = 900
    p.halfLifeHours = 40
    let c = p.clamped()
    #expect(c.manualWeightKg == UserProfile.Bounds.weightKg.lowerBound)
    #expect(c.healthKitWeightKg == UserProfile.Bounds.weightKg.upperBound)
    #expect(c.halfLifeHours == UserProfile.Bounds.halfLifeHours.upperBound)
}

@Test func clampCoversDoseConstantsAndBedtimeFloor() {
    var p = UserProfile.default
    p.bedtimeLimitMg = 0
    p.singleDoseMgPerKg = 0
    p.singleDoseCapMg = 5
    let c = p.clamped()
    #expect(c.bedtimeLimitMg == UserProfile.Bounds.bedtimeLimitMg.lowerBound)
    #expect(c.singleDoseMgPerKg == UserProfile.Bounds.singleDoseMgPerKg.lowerBound)
    #expect(c.singleDoseCapMg == UserProfile.Bounds.singleDoseCapMg.lowerBound)
}

@Test func levelStatusFromRatio() {
    #expect(LevelStatus(ratio: 0.2, elevatedAt: 0.6) == .ok)
    #expect(LevelStatus(ratio: 0.6, elevatedAt: 0.6) == .elevated)
    #expect(LevelStatus(ratio: 1.0, elevatedAt: 0.6) == .high)
    #expect(LevelStatus.high > LevelStatus.elevated && LevelStatus.elevated > LevelStatus.ok)
}

@Test func clockTimeMinutesOfDay() {
    #expect(ClockTime(hour: 23, minute: 30).minutesOfDay == 1410)
}

@Test func doseIsCodableRoundTrip() throws {
    let d = CaffeineDose(id: UUID(), date: Date(timeIntervalSince1970: 1_000), milligrams: 63, drinkID: "espresso", volumeML: 30)
    let data = try JSONEncoder().encode(d)
    #expect(try JSONDecoder().decode(CaffeineDose.self, from: data) == d)
}

@Test func profileKeepsHealthKitWeightDateAndDecodesWithoutIt() throws {
    var p = UserProfile.default
    p.healthKitWeightKg = 80
    p.healthKitWeightDate = Date(timeIntervalSince1970: 1_700_000_000)
    let data = try JSONEncoder().encode(p)
    #expect(try JSONDecoder().decode(UserProfile.self, from: data) == p)
    // Profil enregistré avant l'ajout du champ (build 2) : la clé est absente, le décodage doit passer.
    var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    json.removeValue(forKey: "healthKitWeightDate")
    let legacy = try JSONDecoder().decode(UserProfile.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(legacy.healthKitWeightKg == 80)
    #expect(legacy.healthKitWeightDate == nil)
}

// MARK: - Profil v0.2 : coucher effectif et options de notification (M6.2)

/// JSON tel que l'encodeur synthétisé de v0.1 l'écrivait : les optionnels à `nil` sont omis, aucune clé v0.2.
private let profileV1JSON = """
{"manualWeightKg":72,"halfLifeHours":6,"bedtime":{"hour":22,"minute":45},"dailyLimitMg":300,
 "bedtimeLimitMg":40,"singleDoseMgPerKg":3,"singleDoseCapMg":200}
"""

@Test func profileV1JSONDecodesWithV2Defaults() throws {
    let p = try JSONDecoder().decode(UserProfile.self, from: Data(profileV1JSON.utf8))
    #expect(p.usesHealthBedtime == false)
    #expect(p.healthBedtime == nil)
    #expect(p.healthBedtimeNights == nil)
    #expect(p.notifySleepReady == false)
    #expect(p.notifyLastIntake == false)
    // Les anciennes valeurs sont intactes.
    #expect(p.manualWeightKg == 72)
    #expect(p.healthKitWeightKg == nil)
    #expect(p.halfLifeHours == 6)
    #expect(p.bedtime == ClockTime(hour: 22, minute: 45))
    #expect(p.dailyLimitMg == 300)
    #expect(p.bedtimeLimitMg == 40)
    #expect(p.singleDoseMgPerKg == 3)
    #expect(p.singleDoseCapMg == 200)
}

@Test func profileV2FieldsSurviveCodableRoundTrip() throws {
    var p = UserProfile.default
    p.usesHealthBedtime = true
    p.healthBedtime = ClockTime(hour: 22, minute: 30)
    p.healthBedtimeNights = 9
    p.notifySleepReady = true
    p.notifyLastIntake = true
    let decoded = try JSONDecoder().decode(UserProfile.self, from: try JSONEncoder().encode(p))
    #expect(decoded == p)
    #expect(decoded.usesHealthBedtime && decoded.notifySleepReady && decoded.notifyLastIntake)
    #expect(decoded.healthBedtime == ClockTime(hour: 22, minute: 30))
    #expect(decoded.healthBedtimeNights == 9)
}

@Test func effectiveBedtimeFallsBackToManualUnlessHealthOptedInWithValue() {
    var p = UserProfile.default
    p.bedtime = ClockTime(hour: 23, minute: 0)
    p.healthBedtime = ClockTime(hour: 22, minute: 15)
    // Option inactive : le manuel, même si Santé a une valeur.
    p.usesHealthBedtime = false
    #expect(p.effectiveBedtime == ClockTime(hour: 23, minute: 0))
    // Option active sans valeur déduite : le manuel.
    p.usesHealthBedtime = true
    p.healthBedtime = nil
    #expect(p.effectiveBedtime == ClockTime(hour: 23, minute: 0))
    // Option active avec valeur : Santé.
    p.healthBedtime = ClockTime(hour: 22, minute: 15)
    #expect(p.effectiveBedtime == ClockTime(hour: 22, minute: 15))
    #expect(p.bedtime == ClockTime(hour: 23, minute: 0))   // le manuel n'est jamais écrasé
}

@Test func clampedKeepsV2Fields() {
    var p = UserProfile.default
    p.usesHealthBedtime = true
    p.healthBedtime = ClockTime(hour: 21, minute: 50)
    p.healthBedtimeNights = 12
    p.notifySleepReady = true
    p.notifyLastIntake = true
    p.halfLifeHours = 40   // hors bornes : clamped() doit modifier sans perdre le reste
    let c = p.clamped()
    #expect(c.halfLifeHours == UserProfile.Bounds.halfLifeHours.upperBound)
    #expect(c.usesHealthBedtime && c.notifySleepReady && c.notifyLastIntake)
    #expect(c.healthBedtime == ClockTime(hour: 21, minute: 50))
    #expect(c.healthBedtimeNights == 12)
}
