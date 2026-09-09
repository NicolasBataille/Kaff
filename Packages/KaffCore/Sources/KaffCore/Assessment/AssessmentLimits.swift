import Foundation

/// Seuils et paramètres dérivés du profil, seuls nécessaires à `LevelAssessor`. C'est ce que reçoit la complication
/// via le snapshot de l'App Group : la limite de pic est déjà calculée, le poids brut ne quitte pas l'app
/// (revue sécurité M5.4). Invariant : rien de dérivé du poids ne traverse l'App Group hormis `peakLimitMg`
/// (3 mg/kg × poids sous le plafond de 200 mg — choix assumé depuis M5.6, conteneur signé par la même équipe).
/// L'affichage en mg/L, qui aurait ajouté un volume de distribution ici, est abandonné le 2026-09-09 (idée en backlog) ;
/// un blob v3 qui porte encore `distributionLitres` / `complicationUnit` se relit tel quel (clés inconnues ignorées).
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
    /// `bedtime` est le coucher effectif (spec §5.1) : Santé si l'option est active et une valeur déduite existe,
    /// sinon la saisie manuelle — le widget le reçoit tel quel, sans changement de schéma.
    public init(profile: UserProfile) {
        self.init(halfLifeHours: profile.halfLifeHours, bedtime: profile.effectiveBedtime,
                  peakLimitMg: profile.peakLimitMg,
                  dailyLimitMg: profile.dailyLimitMg, bedtimeLimitMg: profile.bedtimeLimitMg)
    }
}
