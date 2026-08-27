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
        halfLifeHours: 5,                // Source: EFSA 2015, demi-vie médiane adulte ~5 h (fourchette 1,5–9,5 h)
        bedtime: ClockTime(hour: 23, minute: 0),
        dailyLimitMg: 400,               // Source: EFSA 2015 / FDA, apport journalier sans risque adulte
        bedtimeLimitMg: 50,              // Source: choix produit ; ≈ une demi-tasse restante au coucher. À affiner.
        singleDoseMgPerKg: 3,            // Source: EFSA 2015, dose unique sans risque ≈ 3 mg/kg
        singleDoseCapMg: 200             // Source: EFSA 2015, dose unique ≤ 200 mg
    )

    /// Poids effectif : manuel > HealthKit > repli.
    public var weightKg: Double { manualWeightKg ?? healthKitWeightKg ?? Self.fallbackWeightKg }
    /// `true` quand on utilise le poids de repli (badge « poids estimé » dans l'UI).
    public var isWeightEstimated: Bool { manualWeightKg == nil && healthKitWeightKg == nil }

    /// Dose ponctuelle maximale pour ce poids.
    public var singleDoseLimitMg: Double { min(singleDoseMgPerKg * weightKg, singleDoseCapMg) }

    public enum Bounds {
        public static let weightKg = 30.0...250.0
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
