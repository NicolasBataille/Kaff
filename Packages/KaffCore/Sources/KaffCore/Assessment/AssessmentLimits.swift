import Foundation

/// Seuils et paramètres dérivés du profil, seuls nécessaires à `LevelAssessor`. C'est ce que reçoit la complication
/// via le snapshot de l'App Group : la limite de pic est déjà calculée, le poids brut ne quitte pas l'app
/// (revue sécurité M5.4). Depuis v0.3 (spec §2, §5.3) le volume de distribution `distributionLitres` — 0,67 × poids
/// arrondi à 2 L, soit une ambiguïté d'≈ 3 kg sur le poids — traverse l'App Group ; `peakLimitMg` (3 mg/kg × poids sous 200 mg) donnait déjà le poids sous 66,7 kg depuis M5.6, choix assumé : conteneur signé par la même équipe : le widget en a besoin pour afficher des mg/L.
public struct AssessmentLimits: Hashable, Codable, Sendable {
    public let halfLifeHours: Double
    public let bedtime: ClockTime
    /// Charge corporelle maximale (mg dans l'organisme), comparée à `currentMg` — pas la dose ingérée.
    public let peakLimitMg: Double
    public let dailyLimitMg: Double
    public let bedtimeLimitMg: Double
    /// Volume de distribution V (L), dénominateur de toute concentration : C = mg / V (spec §5.3).
    public let distributionLitres: Double
    /// Unité affichée par la complication ; l'anneau n'en dépend jamais (C / C_limite = A / A_limite).
    public let complicationUnit: DisplayUnit

    /// Volume quand le snapshot n'en porte pas (blob v3 antérieur à M7.1) : celui du poids de repli, 70 kg → 46 L.
    public static let defaultDistributionLitres = UserProfile.default.distributionLitres

    public init(halfLifeHours: Double, bedtime: ClockTime, peakLimitMg: Double,
                dailyLimitMg: Double, bedtimeLimitMg: Double,
                distributionLitres: Double = AssessmentLimits.defaultDistributionLitres,
                complicationUnit: DisplayUnit = .milligrams) {
        self.halfLifeHours = halfLifeHours
        self.bedtime = bedtime
        self.peakLimitMg = peakLimitMg
        self.dailyLimitMg = dailyLimitMg
        self.bedtimeLimitMg = bedtimeLimitMg
        self.distributionLitres = distributionLitres
        self.complicationUnit = complicationUnit
    }

    /// Dérive les seuils du profil (`peakLimitMg` = min(mg/kg × poids, plafond) × fraction au pic du modèle PK).
    /// `bedtime` est le coucher effectif (spec §5.1) : Santé si l'option est active et une valeur déduite existe,
    /// sinon la saisie manuelle — le widget le reçoit tel quel, sans changement de schéma.
    public init(profile: UserProfile) {
        self.init(halfLifeHours: profile.halfLifeHours, bedtime: profile.effectiveBedtime,
                  peakLimitMg: profile.peakLimitMg,
                  dailyLimitMg: profile.dailyLimitMg, bedtimeLimitMg: profile.bedtimeLimitMg,
                  distributionLitres: profile.distributionLitres, complicationUnit: profile.complicationUnit)
    }

    private enum CodingKeys: String, CodingKey {
        case halfLifeHours, bedtime, peakLimitMg, dailyLimitMg, bedtimeLimitMg
        case distributionLitres, complicationUnit
    }

    /// Décodage tolérant : `distributionLitres` et `complicationUnit` sont absents des blobs v3 écrits avant M7.1
    /// (même clé `cache.snapshot.v3`). Un volume altéré (≤ 0 ou non fini) retombe sur le volume par défaut plutôt que
    /// de produire une division par zéro ou une concentration infinie dans le widget.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let litres = try c.decodeIfPresent(Double.self, forKey: .distributionLitres) ?? Self.defaultDistributionLitres
        self.init(
            halfLifeHours: try c.decode(Double.self, forKey: .halfLifeHours),
            bedtime: try c.decode(ClockTime.self, forKey: .bedtime),
            peakLimitMg: try c.decode(Double.self, forKey: .peakLimitMg),
            dailyLimitMg: try c.decode(Double.self, forKey: .dailyLimitMg),
            bedtimeLimitMg: try c.decode(Double.self, forKey: .bedtimeLimitMg),
            distributionLitres: litres.isFinite && litres > 0 ? litres : Self.defaultDistributionLitres,
            // Valeur inconnue → unité par défaut plutôt que perdre tout le snapshot (revue sécurité M7.5).
            complicationUnit: try c.decodeIfPresent(String.self, forKey: .complicationUnit).flatMap(DisplayUnit.init(rawValue:)) ?? .milligrams
        )
    }

    /// Limite de pic en concentration (mg/L) : `peakLimitMg / distributionLitres`.
    public var peakLimitMgPerLitre: Double { peakLimitMg / distributionLitres }

    /// Seuil de coucher en concentration (mg/L) : `bedtimeLimitMg / distributionLitres`.
    public var bedtimeLimitMgPerLitre: Double { bedtimeLimitMg / distributionLitres }
}
