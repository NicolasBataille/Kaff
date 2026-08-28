import Foundation

/// Tout ce qu'une entrée de complication doit afficher, précalculé.
public struct WidgetEntryData: Hashable, Sendable {
    public let date: Date
    public let milligrams: Double
    public let status: LevelStatus
    public let limitMg: Double
    public let sleepReadyAt: Date
    public let isSleepReady: Bool
    /// `false` quand aucun snapshot n'existe (app jamais ouverte).
    public let hasData: Bool
    /// Niveau (mg) échantillonné toutes les `WidgetTimelinePlanner.sparklineStepMinutes` à partir de `date`
    /// (`WidgetTimelinePlanner.sparklineSamples` points, ≈ 6 h) pour la mini-courbe de la famille rectangulaire.
    public let sparkline: [Double]

    public init(date: Date, milligrams: Double, status: LevelStatus, limitMg: Double,
                sleepReadyAt: Date, isSleepReady: Bool, hasData: Bool, sparkline: [Double] = []) {
        self.date = date
        self.milligrams = milligrams
        self.status = status
        self.limitMg = limitMg
        self.sleepReadyAt = sleepReadyAt
        self.isSleepReady = isSleepReady
        self.hasData = hasData
        self.sparkline = sparkline
    }

    public static func empty(at date: Date) -> WidgetEntryData {
        WidgetEntryData(date: date, milligrams: 0, status: .ok, limitMg: UserProfile.default.singleDoseLimitMg,
                        sleepReadyAt: date, isSleepReady: true, hasData: false,
                        sparkline: Array(repeating: 0, count: WidgetTimelinePlanner.sparklineSamples))
    }
}
