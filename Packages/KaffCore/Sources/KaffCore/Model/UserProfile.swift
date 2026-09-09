import Foundation

/// Réglages utilisateur qui paramètrent le modèle et les seuils.
public struct UserProfile: Hashable, Codable, Sendable {
    /// Source: valeur de repli quand ni HealthKit ni l'utilisateur ne fournissent de poids.
    public static let fallbackWeightKg = 70.0

    /// Dernier poids lu dans HealthKit (`bodyMass`), rafraîchi par l'app.
    public var healthKitWeightKg: Double?
    /// Date de cette pesée (affichée dans Réglages ; la base Santé de la montre ne garde que des échantillons récents).
    public var healthKitWeightDate: Date?
    /// Surcharge saisie dans Réglages ; prioritaire sur HealthKit.
    public var manualWeightKg: Double?
    public var halfLifeHours: Double
    public var bedtime: ClockTime
    public var dailyLimitMg: Double
    public var bedtimeLimitMg: Double
    public var singleDoseMgPerKg: Double
    public var singleDoseCapMg: Double

    // Champs v0.2 (spec §5.1) — tous facultatifs au décodage pour rester compatibles avec un profil v0.1.

    /// L'utilisateur a choisi le coucher déduit du sommeil Santé.
    public var usesHealthBedtime: Bool = false
    /// Dernière valeur déduite des sessions `sleepAnalysis` (`nil` : aucune nuit exploitable).
    public var healthBedtime: ClockTime?
    /// Nombre de nuits sur lesquelles repose `healthBedtime` (affiché dans Réglages).
    public var healthBedtimeNights: Int?
    public var notifySleepReady: Bool = false
    public var notifyLastIntake: Bool = false

    public init(healthKitWeightKg: Double? = nil, healthKitWeightDate: Date? = nil, manualWeightKg: Double? = nil,
                halfLifeHours: Double, bedtime: ClockTime,
                dailyLimitMg: Double, bedtimeLimitMg: Double, singleDoseMgPerKg: Double, singleDoseCapMg: Double,
                usesHealthBedtime: Bool = false, healthBedtime: ClockTime? = nil, healthBedtimeNights: Int? = nil,
                notifySleepReady: Bool = false, notifyLastIntake: Bool = false) {
        self.healthKitWeightKg = healthKitWeightKg
        self.healthKitWeightDate = healthKitWeightDate
        self.manualWeightKg = manualWeightKg
        self.halfLifeHours = halfLifeHours
        self.bedtime = bedtime
        self.dailyLimitMg = dailyLimitMg
        self.bedtimeLimitMg = bedtimeLimitMg
        self.singleDoseMgPerKg = singleDoseMgPerKg
        self.singleDoseCapMg = singleDoseCapMg
        self.usesHealthBedtime = usesHealthBedtime
        self.healthBedtime = healthBedtime
        self.healthBedtimeNights = healthBedtimeNights
        self.notifySleepReady = notifySleepReady
        self.notifyLastIntake = notifyLastIntake
    }

    // Clés = noms des propriétés : les anciennes pour lire un profil v0.1, les nouvelles sont celles que l'app
    // (M6.4) écrit. L'encodage reste synthétisé ; seul le décodage est explicite.
    private enum CodingKeys: String, CodingKey {
        case healthKitWeightKg, healthKitWeightDate, manualWeightKg
        case halfLifeHours, bedtime, dailyLimitMg, bedtimeLimitMg, singleDoseMgPerKg, singleDoseCapMg
        case usesHealthBedtime, healthBedtime, healthBedtimeNights, notifySleepReady, notifyLastIntake
    }

    /// Décodage tolérant : un profil enregistré par v0.1 n'a aucune clé v0.2, elles prennent leurs valeurs par défaut.
    /// Les clés v0.1 restent obligatoires : un blob corrompu doit échouer (et `ProfileStore` retombe sur `.default`).
    /// Une clé inconnue (ex. `complicationUnit` écrite par un build v0.3 intermédiaire) est ignorée.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            healthKitWeightKg: try c.decodeIfPresent(Double.self, forKey: .healthKitWeightKg),
            healthKitWeightDate: try c.decodeIfPresent(Date.self, forKey: .healthKitWeightDate),
            manualWeightKg: try c.decodeIfPresent(Double.self, forKey: .manualWeightKg),
            halfLifeHours: try c.decode(Double.self, forKey: .halfLifeHours),
            bedtime: try c.decode(ClockTime.self, forKey: .bedtime),
            dailyLimitMg: try c.decode(Double.self, forKey: .dailyLimitMg),
            bedtimeLimitMg: try c.decode(Double.self, forKey: .bedtimeLimitMg),
            singleDoseMgPerKg: try c.decode(Double.self, forKey: .singleDoseMgPerKg),
            singleDoseCapMg: try c.decode(Double.self, forKey: .singleDoseCapMg),
            usesHealthBedtime: try c.decodeIfPresent(Bool.self, forKey: .usesHealthBedtime) ?? false,
            healthBedtime: try c.decodeIfPresent(ClockTime.self, forKey: .healthBedtime),
            healthBedtimeNights: try c.decodeIfPresent(Int.self, forKey: .healthBedtimeNights),
            notifySleepReady: try c.decodeIfPresent(Bool.self, forKey: .notifySleepReady) ?? false,
            notifyLastIntake: try c.decodeIfPresent(Bool.self, forKey: .notifyLastIntake) ?? false
        )
    }

    public static let `default` = UserProfile(
        // Source: IOM 2001, moyenne ≈ 5 h (1,5–9,5 h) ; EFSA 2015 : ≈ 4 h (2–8 h)
        halfLifeHours: 5,
        bedtime: ClockTime(hour: 23, minute: 0),
        // Source: EFSA 2015 (400 mg/j « consommés au cours de la journée », consommation habituelle) ; FDA idem
        dailyLimitMg: 400,
        // Source: Gardiner 2023 — café 107 mg ≥ 8,8 h et pré-workout 217,5 mg ≥ 13,2 h avant le coucher ;
        // résidu avec Bateman (ka 5, t½ 5 h) = 32,5 et 35,9 mg → 35 mg. Borne haute absolue : 100 mg près du
        // coucher peut perturber le sommeil (EFSA 2015)
        bedtimeLimitMg: 35,
        // Source: EFSA 2015, dose unique 200 mg ≈ 3 mg/kg pc (quantité ingérée)
        singleDoseMgPerKg: 3,
        singleDoseCapMg: 200
    )

    /// Coucher effectif (spec §5.1) : la valeur Santé quand l'option est active et qu'une valeur a pu être déduite,
    /// sinon la saisie manuelle `bedtime`, jamais écrasée. C'est ce qui alimente `AssessmentLimits.bedtime`.
    public var effectiveBedtime: ClockTime {
        guard usesHealthBedtime, let healthBedtime else { return bedtime }
        return healthBedtime
    }

    /// Poids effectif : manuel > HealthKit > repli.
    public var weightKg: Double { manualWeightKg ?? healthKitWeightKg ?? Self.fallbackWeightKg }
    /// `true` quand on utilise le poids de repli (badge « poids estimé » dans l'UI).
    public var isWeightEstimated: Bool { manualWeightKg == nil && healthKitWeightKg == nil }

    /// Dose ponctuelle maximale pour ce poids (quantité ingérée, affichée dans Réglages).
    public var singleDoseLimitMg: Double { min(singleDoseMgPerKg * weightKg, singleDoseCapMg) }

    /// Charge corporelle maximale : Cmax d'une dose unique à la limite (EFSA 2015 §5.1.3 : des prises répétées
    /// ne doivent pas dépasser la concentration maximale d'une dose de 200 mg).
    public var peakLimitMg: Double { singleDoseLimitMg * PharmacokineticModel(halfLifeHours: halfLifeHours).peakFraction }

    // MARK: Concentration plasmatique estimée (spec §5.3) — réservé, non affiché en v0.3 (idée en backlog, 2026-09-09).
    // Fonctions pures et testées ; rien ici n'est persisté ni transmis à l'App Group.

    /// Granularité d'arrondi du volume de distribution (L).
    /// Source: choix produit (revue sécurité M7.5) — un pas de 2 L vaut ≈ 3 kg de poids (2 / 0,67) : un poids saisi au kilo
    /// près ne serait pas inversible si le volume devait un jour quitter l'app (à 0,5 L, chaque kilo donnait un volume
    /// distinct). Le volume reste à ± 2 % près, négligeable devant la variabilité du Vd publié (0,5–0,75 L/kg).
    public static let distributionRoundingLitres = 2.0

    /// Volume de distribution V = Vd × poids (L), arrondi au `distributionRoundingLitres` le plus proche : 70 kg → 46,9 → 46 L.
    /// Réservé, non affiché en v0.3 (idée en backlog) : ne traverse pas l'App Group.
    public var distributionLitres: Double {
        let step = Self.distributionRoundingLitres
        return (PharmacokineticModel.distributionLitresPerKg * weightKg / step).rounded() * step
    }

    /// Limite de pic en concentration (mg/L) : `peakLimitMg / V`. Sous le plafond de 200 mg, ≈ 3 mg/kg × pic / 0,67
    /// ≈ 4,04 mg/L quel que soit le poids ; au-delà elle décroît avec le poids. Réservé, non affiché en v0.3.
    public var peakLimitMgPerLitre: Double { peakLimitMg / distributionLitres }

    /// Seuil de coucher en concentration (mg/L) : `bedtimeLimitMg / V`. Réservé, non affiché en v0.3.
    public var bedtimeLimitMgPerLitre: Double { bedtimeLimitMg / distributionLitres }

    public enum Bounds {
        public static let weightKg = 30.0...250.0
        /// Source: couvre EFSA 2–8 h et IOM 1,5–9,5 h ; hors bornes (documenté) : grossesse T3 11,5–18 h, fluvoxamine 31 h.
        public static let halfLifeHours = 2.0...10.0
        public static let dailyLimitMg = 50.0...1000.0
        /// Source: revue de code M1 — 0 mg est inatteignable avec une décroissance exponentielle.
        public static let bedtimeLimitMg = 10.0...300.0
        public static let doseMg = 0.0...1000.0
        public static let singleDoseMgPerKg = 1.0...10.0
        public static let singleDoseCapMg = 50.0...1000.0
    }

    /// Copie dont chaque champ est ramené dans ses bornes.
    public func clamped() -> UserProfile {
        var c = self
        c.manualWeightKg = manualWeightKg.map { min(max($0, Bounds.weightKg.lowerBound), Bounds.weightKg.upperBound) }
        c.healthKitWeightKg = healthKitWeightKg.map { min(max($0, Bounds.weightKg.lowerBound), Bounds.weightKg.upperBound) }
        c.halfLifeHours = min(max(halfLifeHours, Bounds.halfLifeHours.lowerBound), Bounds.halfLifeHours.upperBound)
        c.dailyLimitMg = min(max(dailyLimitMg, Bounds.dailyLimitMg.lowerBound), Bounds.dailyLimitMg.upperBound)
        c.bedtimeLimitMg = min(max(bedtimeLimitMg, Bounds.bedtimeLimitMg.lowerBound), Bounds.bedtimeLimitMg.upperBound)
        c.singleDoseMgPerKg = min(max(singleDoseMgPerKg, Bounds.singleDoseMgPerKg.lowerBound), Bounds.singleDoseMgPerKg.upperBound)
        c.singleDoseCapMg = min(max(singleDoseCapMg, Bounds.singleDoseCapMg.lowerBound), Bounds.singleDoseCapMg.upperBound)
        return c
    }
}
