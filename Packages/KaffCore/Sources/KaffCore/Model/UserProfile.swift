import Foundation

/// Réglages utilisateur qui paramètrent le modèle et les seuils.
public struct UserProfile: Hashable, Codable, Sendable {
    /// Source: valeur de repli quand ni HealthKit ni l'utilisateur ne fournissent de poids.
    public static let fallbackWeightKg = 70.0

    /// Dernier poids lu dans HealthKit (`bodyMass`), rafraîchi par l'app.
    public var healthKitWeightKg: Double?
    /// Surcharge saisie dans Réglages ; prioritaire sur HealthKit.
    public var manualWeightKg: Double?
    public var halfLifeHours: Double
    public var bedtime: ClockTime
    public var dailyLimitMg: Double
    public var bedtimeLimitMg: Double
    public var singleDoseMgPerKg: Double
    public var singleDoseCapMg: Double

    public init(healthKitWeightKg: Double? = nil, manualWeightKg: Double? = nil, halfLifeHours: Double, bedtime: ClockTime,
                dailyLimitMg: Double, bedtimeLimitMg: Double, singleDoseMgPerKg: Double, singleDoseCapMg: Double) {
        self.healthKitWeightKg = healthKitWeightKg
        self.manualWeightKg = manualWeightKg
        self.halfLifeHours = halfLifeHours
        self.bedtime = bedtime
        self.dailyLimitMg = dailyLimitMg
        self.bedtimeLimitMg = bedtimeLimitMg
        self.singleDoseMgPerKg = singleDoseMgPerKg
        self.singleDoseCapMg = singleDoseCapMg
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

    /// Poids effectif : manuel > HealthKit > repli.
    public var weightKg: Double { manualWeightKg ?? healthKitWeightKg ?? Self.fallbackWeightKg }
    /// `true` quand on utilise le poids de repli (badge « poids estimé » dans l'UI).
    public var isWeightEstimated: Bool { manualWeightKg == nil && healthKitWeightKg == nil }

    /// Dose ponctuelle maximale pour ce poids.
    public var singleDoseLimitMg: Double { min(singleDoseMgPerKg * weightKg, singleDoseCapMg) }

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
