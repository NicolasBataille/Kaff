import Foundation

/// Tout ce qu'une entrée de complication doit afficher, précalculé.
public struct WidgetEntryData: Hashable, Sendable {
    public let date: Date
    public let milligrams: Double
    public let status: LevelStatus
    /// Limite de pic (charge corporelle), dénominateur de l'anneau et repère de la sparkline.
    public let limitMg: Double
    public let sleepReadyAt: Date
    public let isSleepReady: Bool
    /// `false` quand aucun snapshot n'existe (app jamais ouverte).
    public let hasData: Bool
    /// Niveau (mg) échantillonné toutes les `WidgetTimelinePlanner.sparklineStepMinutes` à partir de `date`
    /// (`WidgetTimelinePlanner.sparklineSamples` points, ≈ 6 h) pour la mini-courbe de la famille rectangulaire.
    public let sparkline: [Double]
    /// `true` quand, à `date`, le snapshot est plus vieux que sa fenêtre de doses (`CacheSnapshot.windowHours`) :
    /// une dose non transmise ne peut plus être connue. Le rectangulaire et l'inline affichent alors « Ouvrir Kaff »
    /// en ligne secondaire ; la valeur reste juste (la caféine connue a décru). `false` sans snapshot.
    public let isStale: Bool
    /// Concentration plasmatique estimée (spec §5.3) : `milligrams / limits.distributionLitres`, non arrondie
    /// (la mise en forme à une décimale est celle du widget). L'anneau reste sur `milligrams / limitMg`.
    public let milligramsPerLitre: Double
    /// Unité à afficher, `limits.complicationUnit` (spec §8) ; ne change ni le nombre en mg ni l'anneau.
    public let unit: DisplayUnit

    public init(date: Date, milligrams: Double, status: LevelStatus, limitMg: Double,
                sleepReadyAt: Date, isSleepReady: Bool, hasData: Bool, sparkline: [Double] = [],
                isStale: Bool = false, milligramsPerLitre: Double = 0, unit: DisplayUnit = .milligrams) {
        self.date = date
        self.milligrams = milligrams
        self.status = status
        self.limitMg = limitMg
        self.sleepReadyAt = sleepReadyAt
        self.isSleepReady = isSleepReady
        self.hasData = hasData
        self.sparkline = sparkline
        self.isStale = isStale
        self.milligramsPerLitre = milligramsPerLitre
        self.unit = unit
    }

    public static func empty(at date: Date) -> WidgetEntryData {
        WidgetEntryData(date: date, milligrams: 0, status: .ok, limitMg: UserProfile.default.peakLimitMg,
                        sleepReadyAt: date, isSleepReady: true, hasData: false,
                        sparkline: Array(repeating: 0, count: WidgetTimelinePlanner.sparklineSamples),
                        milligramsPerLitre: 0, unit: .milligrams)
    }
}
