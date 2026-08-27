import Foundation

/// Résultat d'une évaluation à un instant donné.
public struct LevelAssessment: Hashable, Sendable {
    public let now: Date
    public let currentMg: Double
    public let dailyTotalMg: Double
    public let bedtime: Date
    public let projectedBedtimeMg: Double
    /// Premier instant (≥ `now`) où le niveau passe sous le seuil de coucher. `== now` si c'est déjà le cas.
    public let sleepReadyAt: Date
    public let peakStatus: LevelStatus
    public let dailyStatus: LevelStatus
    public let bedtimeStatus: LevelStatus

    public var status: LevelStatus { max(peakStatus, max(dailyStatus, bedtimeStatus)) }

    /// Vérification qui impose le statut (priorité pic > coucher > journée).
    public var reason: LevelReason {
        guard status != .ok else { return .none }
        if peakStatus == status { return .peak }
        if bedtimeStatus == status { return .bedtime }
        return .daily
    }

    public var isSleepReady: Bool { sleepReadyAt <= now }
}
