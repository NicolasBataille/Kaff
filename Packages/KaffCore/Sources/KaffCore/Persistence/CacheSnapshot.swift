import Foundation

/// Ce que le widget a besoin de connaître : les doses récentes et les seuils dérivés du profil
/// (jamais le profil brut : le poids reste dans l'app).
public struct CacheSnapshot: Hashable, Codable, Sendable {
    public let doses: [CaffeineDose]
    public let limits: AssessmentLimits
    /// Non lu en v1 ; réservé à un indicateur d'obsolescence (backlog).
    public let updatedAt: Date

    public init(doses: [CaffeineDose], limits: AssessmentLimits, updatedAt: Date) {
        self.doses = doses
        self.limits = limits
        self.updatedAt = updatedAt
    }
}
