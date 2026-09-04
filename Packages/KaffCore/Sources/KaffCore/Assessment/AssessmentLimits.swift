import Foundation

/// Seuils et paramètres dérivés du profil, seuls nécessaires à `LevelAssessor`. C'est ce que reçoit la complication
/// via le snapshot de l'App Group : la limite de pic est déjà calculée, le poids ne quitte jamais l'app
/// (revue sécurité M5.4).
public struct AssessmentLimits: Hashable, Codable, Sendable {
    public let halfLifeHours: Double
    public let bedtime: ClockTime
    /// Charge corporelle maximale (mg dans l'organisme), comparée à `currentMg` — pas la dose ingérée.
    public let peakLimitMg: Double
    public let dailyLimitMg: Double
    public let bedtimeLimitMg: Double

    public init(halfLifeHours: Double, bedtime: ClockTime, peakLimitMg: Double,
                dailyLimitMg: Double, bedtimeLimitMg: Double) {
        self.halfLifeHours = halfLifeHours
        self.bedtime = bedtime
        self.peakLimitMg = peakLimitMg
        self.dailyLimitMg = dailyLimitMg
        self.bedtimeLimitMg = bedtimeLimitMg
    }

    /// Dérive les seuils du profil (`peakLimitMg` = min(mg/kg × poids, plafond) × fraction au pic du modèle PK).
    public init(profile: UserProfile) {
        self.init(halfLifeHours: profile.halfLifeHours, bedtime: profile.bedtime,
                  peakLimitMg: profile.peakLimitMg,
                  dailyLimitMg: profile.dailyLimitMg, bedtimeLimitMg: profile.bedtimeLimitMg)
    }
}
