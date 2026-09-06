import Foundation

/// Ce que le widget a besoin de connaître : les doses récentes et les seuils dérivés du profil
/// (jamais le profil brut : le poids reste dans l'app).
public struct CacheSnapshot: Hashable, Codable, Sendable {
    /// Fenêtre des doses quand l'app n'en a pas écrit (blob v3 antérieur à M6.6).
    /// Source: plancher de `AppModel.cacheWindowHours` (`max(30, 10 × t½)`).
    public static let defaultWindowHours: Double = 30

    public let doses: [CaffeineDose]
    public let limits: AssessmentLimits
    /// Instant d'écriture par l'app. Lu par `WidgetTimelinePlanner` : passé `windowHours`, le widget ne peut plus
    /// connaître de dose non transmise et l'entrée est marquée `isStale` (spec §8, obsolescence).
    public let updatedAt: Date
    /// Fenêtre (h) des doses conservées, écrite par l'app (`AppModel.cacheWindowHours`) : seuil d'obsolescence.
    public let windowHours: Double

    public init(doses: [CaffeineDose], limits: AssessmentLimits, updatedAt: Date,
                windowHours: Double = CacheSnapshot.defaultWindowHours) {
        self.doses = doses
        self.limits = limits
        self.updatedAt = updatedAt
        self.windowHours = windowHours
    }

    /// Décodage tolérant : `windowHours` est absent des blobs v3 écrits avant M6.6 (même clé `cache.snapshot.v3`).
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        doses = try c.decode([CaffeineDose].self, forKey: .doses)
        limits = try c.decode(AssessmentLimits.self, forKey: .limits)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        windowHours = try c.decodeIfPresent(Double.self, forKey: .windowHours) ?? Self.defaultWindowHours
    }
}
