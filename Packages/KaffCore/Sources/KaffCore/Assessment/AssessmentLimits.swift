import Foundation

/// Seuils et paramètres dérivés du profil, seuls nécessaires à `LevelAssessor`. C'est ce que reçoit la complication
/// via le snapshot de l'App Group : la dose ponctuelle est déjà calculée, le poids ne quitte jamais l'app
/// (revue sécurité M5.4).
public struct AssessmentLimits: Hashable, Codable, Sendable {
    public let halfLifeHours: Double
    public let bedtime: ClockTime
    public let singleDoseLimitMg: Double
    public let dailyLimitMg: Double
    public let bedtimeLimitMg: Double

    public init(halfLifeHours: Double, bedtime: ClockTime, singleDoseLimitMg: Double,
                dailyLimitMg: Double, bedtimeLimitMg: Double) {
        self.halfLifeHours = halfLifeHours
        self.bedtime = bedtime
        self.singleDoseLimitMg = singleDoseLimitMg
        self.dailyLimitMg = dailyLimitMg
        self.bedtimeLimitMg = bedtimeLimitMg
    }

    /// Dérive les seuils du profil (`singleDoseLimitMg` = min(mg/kg × poids, plafond)).
    public init(profile: UserProfile) {
        self.init(halfLifeHours: profile.halfLifeHours, bedtime: profile.bedtime,
                  singleDoseLimitMg: profile.singleDoseLimitMg,
                  dailyLimitMg: profile.dailyLimitMg, bedtimeLimitMg: profile.bedtimeLimitMg)
    }
}
