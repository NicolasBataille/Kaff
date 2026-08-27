import Foundation

/// Applique les trois vérifications de la spec §5 à un jeu de doses.
public struct LevelAssessor: Sendable {
    /// Source: choix produit — fractions à partir desquelles on prévient avant le dépassement.
    public static let elevatedPeakFraction = 0.6
    public static let elevatedDailyFraction = 0.75
    public static let elevatedBedtimeFraction = 0.6
    /// Horizon de recherche de `sleepReadyAt`.
    static let sleepSearchHorizonHours = 72.0

    public let profile: UserProfile
    public let model: PharmacokineticModel
    public let day: CaffeineDay

    public init(profile: UserProfile, calendar: Calendar = .current) {
        self.profile = profile
        self.model = PharmacokineticModel(halfLifeHours: profile.halfLifeHours)
        self.day = CaffeineDay(calendar: calendar)
    }

    public func assess(doses: [CaffeineDose], at now: Date) -> LevelAssessment {
        let past = doses.filter { $0.date <= now }
        let current = model.amount(doses: past, at: now)
        let dayStart = day.start(containing: now)
        let dailyTotal = past.filter { $0.date >= dayStart }.reduce(0) { $0 + $1.milligrams }
        let bedtime = day.nextBedtime(profile.bedtime, after: now)
        let projected = model.amount(doses: past, at: bedtime)
        return LevelAssessment(
            now: now,
            currentMg: current,
            dailyTotalMg: dailyTotal,
            bedtime: bedtime,
            projectedBedtimeMg: projected,
            sleepReadyAt: sleepReadyDate(doses: past, from: now),
            peakStatus: Self.status(current, limit: profile.singleDoseLimitMg, elevatedAt: Self.elevatedPeakFraction),
            dailyStatus: Self.status(dailyTotal, limit: profile.dailyLimitMg, elevatedAt: Self.elevatedDailyFraction),
            bedtimeStatus: Self.status(projected, limit: profile.bedtimeLimitMg, elevatedAt: Self.elevatedBedtimeFraction)
        )
    }

    /// Une limite ≤ 0 (profil corrompu) désactive la vérification plutôt que de diviser par zéro.
    private static func status(_ value: Double, limit: Double, elevatedAt: Double) -> LevelStatus {
        guard limit > 0 else { return .ok }
        return LevelStatus(ratio: value / limit, elevatedAt: elevatedAt)
    }

    /// Après le dernier pic la courbe est strictement décroissante : recherche par dichotomie à la minute près.
    public func sleepReadyDate(doses: [CaffeineDose], from now: Date) -> Date {
        let limit = profile.bedtimeLimitMg
        guard let lastDose = doses.map(\.date).max() else { return now }
        let lastPeak = lastDose.addingTimeInterval(model.timeToPeakHours * 3600)
        let start = max(now, lastPeak)
        guard model.amount(doses: doses, at: start) >= limit else { return start }
        var low = start
        var high = start.addingTimeInterval(Self.sleepSearchHorizonHours * 3600)
        guard model.amount(doses: doses, at: high) < limit else { return high }
        while high.timeIntervalSince(low) > 60 {
            let mid = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
            if model.amount(doses: doses, at: mid) < limit { high = mid } else { low = mid }
        }
        return high
    }
}
