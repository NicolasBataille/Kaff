import Foundation
import Testing
@testable import KaffCore

/// `AssessmentLimits` : ce que le widget reçoit à la place du profil (revue sécurité M5.4 : pas de poids brut).
@Test func limitsDeriveSingleDoseLimitFromProfileWeight() {
    var profile = UserProfile.default
    profile.manualWeightKg = 60
    let limits = AssessmentLimits(profile: profile)
    #expect(limits.singleDoseLimitMg == 180)
    #expect(limits.halfLifeHours == profile.halfLifeHours)
    #expect(limits.bedtime == profile.bedtime)
    #expect(limits.dailyLimitMg == profile.dailyLimitMg)
    #expect(limits.bedtimeLimitMg == profile.bedtimeLimitMg)
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
    #expect(fromLimits.limits.singleDoseLimitMg == 165)
}
