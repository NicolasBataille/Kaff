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

    // Concentration plasmatique estimée (spec §5.3) : C = A / V, avec V = `AssessmentLimits.distributionLitres`.
    // Fonctions pures : l'évaluation reste en mg, le volume est fourni par l'appelant.

    /// Concentration actuelle (mg/L) pour un volume de distribution `litres`.
    public func currentMgPerLitre(litres: Double) -> Double { currentMg / litres }

    /// Concentration projetée au coucher (mg/L) pour un volume de distribution `litres`.
    public func projectedBedtimeMgPerLitre(litres: Double) -> Double { projectedBedtimeMg / litres }
}
