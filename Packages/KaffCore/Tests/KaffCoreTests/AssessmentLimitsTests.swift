import Foundation
import Testing
@testable import KaffCore

/// `AssessmentLimits` : ce que le widget reçoit à la place du profil (revue sécurité M5.4 : pas de poids brut).
/// La limite de pic est la charge corporelle au Cmax d'une dose unique à la limite (EFSA 2015 §5.1.3, M5.6) :
/// 60 kg × 3 mg/kg = 180 mg ingérés → 180 × 0,903 ≈ 162,5 mg dans l'organisme.
@Test func limitsDerivePeakLimitFromProfileWeightAndPeakFraction() {
    var profile = UserProfile.default
    profile.manualWeightKg = 60
    let limits = AssessmentLimits(profile: profile)
    let peakFraction = PharmacokineticModel(halfLifeHours: profile.halfLifeHours).peakFraction
    #expect(profile.singleDoseLimitMg == 180)
    #expect(abs(limits.peakLimitMg - 180 * peakFraction) < 1e-9)
    #expect(abs(limits.peakLimitMg - 162.5) < 0.1)
    #expect(limits.halfLifeHours == profile.halfLifeHours)
    #expect(limits.bedtime == profile.bedtime)
    #expect(limits.dailyLimitMg == profile.dailyLimitMg)
    #expect(limits.bedtimeLimitMg == profile.bedtimeLimitMg)
}

/// Coucher effectif (spec §5.1, M6.2) : l'option Santé active avec une valeur déduite alimente `limits.bedtime` ;
/// le coucher manuel, différent, ne doit pas fuir vers le widget.
@Test func limitsUseEffectiveBedtimeWhenHealthBedtimeIsOptedIn() {
    var profile = UserProfile.default
    profile.bedtime = ClockTime(hour: 23, minute: 0)
    profile.usesHealthBedtime = true
    profile.healthBedtime = ClockTime(hour: 22, minute: 30)
    let limits = AssessmentLimits(profile: profile)
    #expect(limits.bedtime == profile.effectiveBedtime)
    #expect(limits.bedtime == ClockTime(hour: 22, minute: 30))
    #expect(limits.bedtime != profile.bedtime)
}

@Test func limitsEncodeWithoutAnyWeight() throws {
    var profile = UserProfile.default
    profile.healthKitWeightKg = 81.5
    let json = String(decoding: try JSONEncoder().encode(AssessmentLimits(profile: profile)), as: UTF8.self)
    #expect(!json.lowercased().contains("weight"))
    #expect(!json.contains("81.5"))
    let decoded = try JSONDecoder().decode(AssessmentLimits.self, from: Data(json.utf8))
    #expect(decoded == AssessmentLimits(profile: profile))
}

@Test func assessorFromLimitsMatchesAssessorFromProfile() {
    var profile = UserProfile.default
    profile.manualWeightKg = 55
    profile.halfLifeHours = 4
    let doses = [CaffeineDose(date: TestClock.date(9), milligrams: 150), CaffeineDose(date: TestClock.date(14), milligrams: 120)]
    let now = TestClock.date(20)
    let fromProfile = LevelAssessor(profile: profile, calendar: TestClock.calendar)
    let fromLimits = LevelAssessor(limits: AssessmentLimits(profile: profile), calendar: TestClock.calendar)
    #expect(fromProfile.limits == fromLimits.limits)
    #expect(fromProfile.assess(doses: doses, at: now) == fromLimits.assess(doses: doses, at: now))
    // 55 kg × 3 = 165 mg ingérés ; t½ 4 h → tmax 0,697 h, pic 0,886 → 146,2 mg dans l'organisme.
    let peakFraction = PharmacokineticModel(halfLifeHours: 4).peakFraction
    #expect(abs(fromLimits.limits.peakLimitMg - 165 * peakFraction) < 1e-9)
    #expect(abs(fromLimits.limits.peakLimitMg - 146.2) < 0.1)
}
