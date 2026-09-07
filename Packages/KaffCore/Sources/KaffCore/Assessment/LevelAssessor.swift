import Foundation

/// Applique les trois vérifications de la spec §5 à un jeu de doses.
public struct LevelAssessor: Sendable {
    /// Source: choix produit, sans base littéraire — pré-alerte avant le dépassement.
    public static let elevatedPeakFraction = 0.6
    public static let elevatedDailyFraction = 0.75
    public static let elevatedBedtimeFraction = 0.6
    /// Horizon de recherche de `sleepReadyAt`.
    /// Source: borne de recherche généreuse, pas une constante physiologique ; au-delà on retourne la borne.
    static let sleepSearchHorizonHours = 72.0

    public let limits: AssessmentLimits
    public let model: PharmacokineticModel
    public let day: CaffeineDay

    public init(limits: AssessmentLimits, calendar: Calendar = .current) {
        self.limits = limits
        self.model = PharmacokineticModel(halfLifeHours: limits.halfLifeHours)
        self.day = CaffeineDay(calendar: calendar)
    }

    public init(profile: UserProfile, calendar: Calendar = .current) {
        self.init(limits: AssessmentLimits(profile: profile), calendar: calendar)
    }

    public func assess(doses: [CaffeineDose], at now: Date) -> LevelAssessment {
        let c = checks(doses: doses, at: now)
        return LevelAssessment(
            now: now,
            currentMg: c.currentMg,
            dailyTotalMg: c.dailyTotalMg,
            bedtime: c.bedtime,
            projectedBedtimeMg: c.projectedBedtimeMg,
            sleepReadyAt: sleepReadyDate(doses: c.past, from: now),
            peakStatus: c.peakStatus,
            dailyStatus: c.dailyStatus,
            bedtimeStatus: c.bedtimeStatus
        )
    }

    /// Statut global seul, sans la recherche de `sleepReadyAt` (≈ 13 évaluations du modèle économisées).
    /// Strictement égal à `assess(doses:at:).status`.
    public func status(doses: [CaffeineDose], at now: Date) -> LevelStatus {
        checks(doses: doses, at: now).status
    }

    /// Valeurs dérivées du calendrier, constantes sur un intervalle de la journée caféine : à calculer une fois
    /// puis à réutiliser tant que l'instant échantillonné reste `< validUntil` (balayage minute de `TimelineBuilder`).
    public struct DayContext: Hashable, Sendable {
        /// Début (04:00) de la journée caféine.
        public let dayStart: Date
        /// Prochain coucher ; `nil` quand il est déjà passé dans la journée caféine → projection à l'instant lui-même
        /// (sémantique de `CaffeineDay.nextBedtime`).
        public let bedtime: Date?
        /// Premier instant où le contexte cesse d'être valable : le coucher s'il est à venir, sinon le prochain 04:00.
        public let validUntil: Date
    }

    public func dayContext(at date: Date) -> DayContext {
        let nextStart = day.nextStart(after: date)
        let next = day.nextBedtime(limits.bedtime, after: date)
        let bedtime: Date? = next > date ? next : nil
        return DayContext(dayStart: day.start(containing: date), bedtime: bedtime,
                          validUntil: bedtime.map { min($0, nextStart) } ?? nextStart)
    }

    /// Même résultat que `status(doses:at:)` sans consulter le calendrier, pour un `now` dans
    /// `[context.dayStart, context.validUntil)` — `context` doit venir de `dayContext(at:)` sur cet intervalle.
    public func status(doses: [CaffeineDose], at now: Date, context: DayContext) -> LevelStatus {
        checks(doses: doses, at: now, dayStart: context.dayStart, bedtime: context.bedtime ?? now).status
    }

    /// Les trois vérifications de la spec §5 à un instant — seule source des formules, partagée par `assess` et `status`.
    private struct Checks {
        let past: [CaffeineDose]
        let currentMg: Double
        let dailyTotalMg: Double
        let bedtime: Date
        let projectedBedtimeMg: Double
        let peakStatus: LevelStatus
        let dailyStatus: LevelStatus
        let bedtimeStatus: LevelStatus

        var status: LevelStatus { max(peakStatus, max(dailyStatus, bedtimeStatus)) }
    }

    private func checks(doses: [CaffeineDose], at now: Date) -> Checks {
        checks(doses: doses, at: now, dayStart: day.start(containing: now), bedtime: day.nextBedtime(limits.bedtime, after: now))
    }

    /// Cœur unique des formules, calendrier déjà résolu (`bedtime == now` quand le coucher est passé).
    private func checks(doses: [CaffeineDose], at now: Date, dayStart: Date, bedtime: Date) -> Checks {
        let past = doses.filter { $0.date <= now }
        let current = model.amount(doses: past, at: now)
        let dailyTotal = past.filter { $0.date >= dayStart }.reduce(0) { $0 + $1.milligrams }
        let projected = model.amount(doses: past, at: bedtime)
        return Checks(
            past: past,
            currentMg: current,
            dailyTotalMg: dailyTotal,
            bedtime: bedtime,
            projectedBedtimeMg: projected,
            peakStatus: Self.status(current, limit: limits.peakLimitMg, elevatedAt: Self.elevatedPeakFraction),
            dailyStatus: Self.status(dailyTotal, limit: limits.dailyLimitMg, elevatedAt: Self.elevatedDailyFraction),
            bedtimeStatus: Self.status(projected, limit: limits.bedtimeLimitMg, elevatedAt: Self.elevatedBedtimeFraction)
        )
    }

    /// Une limite ≤ 0 (profil corrompu) désactive la vérification plutôt que de diviser par zéro.
    private static func status(_ value: Double, limit: Double, elevatedAt: Double) -> LevelStatus {
        guard limit > 0 else { return .ok }
        return LevelStatus(ratio: value / limit, elevatedAt: elevatedAt)
    }

    /// Instant à partir duquel la courbe ne fait que décroître : `now`, ou le pic de la dernière dose s'il est à venir.
    private func decayStart(doses: [CaffeineDose], from now: Date) -> Date {
        guard let lastDose = doses.map(\.date).max() else { return now }
        return max(now, lastDose.addingTimeInterval(model.timeToPeakHours * 3600))
    }

    /// `true` si le niveau atteint encore le seuil coucher à `decayStart` : `sleepReadyDate` a alors quelque chose
    /// à annoncer ; sinon elle renvoie simplement cet instant (rien n'a été dépassé).
    public func exceedsBedtimeLimitAfterLastPeak(doses: [CaffeineDose], from now: Date) -> Bool {
        model.amount(doses: doses, at: decayStart(doses: doses, from: now)) >= limits.bedtimeLimitMg
    }

    /// Après le dernier pic la courbe est strictement décroissante : recherche par dichotomie à la minute près.
    public func sleepReadyDate(doses: [CaffeineDose], from now: Date) -> Date {
        let limit = limits.bedtimeLimitMg
        let start = decayStart(doses: doses, from: now)
        guard exceedsBedtimeLimitAfterLastPeak(doses: doses, from: now) else { return start }
        var low = start
        var high = start.addingTimeInterval(Self.sleepSearchHorizonHours * 3600)
        // Plafond d'horizon, pas une vraie estimation : le niveau n'est pas redescendu en 72 h.
        guard model.amount(doses: doses, at: high) < limit else { return high }
        while high.timeIntervalSince(low) > 60 {
            let mid = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
            if model.amount(doses: doses, at: mid) < limit { high = mid } else { low = mid }
        }
        return high
    }

    /// Dernier instant `t ≥ now` où une dose de `milligrams` garde `A_total(coucher) < limits.bedtimeLimitMg` (spec §5.2).
    /// Une prise après `coucher − tmax` culmine pendant le sommeil : jamais proposée, l'intervalle s'arrête là.
    /// `nil` : coucher déjà passé dans la journée caféine, `now > coucher − tmax` (intervalle vide), ou `now` lui-même
    /// dépasse déjà le seuil (« plus de caféine aujourd'hui »). Une limite ≤ 0 (profil corrompu) désactive la recherche.
    public func latestIntakeDate(milligrams: Double, doses: [CaffeineDose], from now: Date) -> Date? {
        let limit = limits.bedtimeLimitMg
        guard limit > 0, let bedtime = dayContext(at: now).bedtime,
              let upper = unconstrainedIntakeBound(from: now), upper >= now else { return nil }
        let past = doses.filter { $0.date <= now }
        // Sur [now, coucher − tmax], A_total(coucher) est croissante en t (la dose a moins de temps pour s'éliminer).
        let projected: (Date) -> Double = { t in
            model.amount(doses: past + [CaffeineDose(date: t, milligrams: milligrams)], at: bedtime)
        }
        guard projected(now) < limit else { return nil }
        guard projected(upper) >= limit else { return upper }
        return Self.lastMinute(below: limit, in: now...upper, value: projected)
    }

    /// `coucher − tmax` : borne haute de `latestIntakeDate`, retournée telle quelle quand la dose passe partout ;
    /// `nil` quand le coucher est déjà passé dans la journée caféine.
    public func unconstrainedIntakeBound(from now: Date) -> Date? {
        dayContext(at: now).bedtime?.addingTimeInterval(-model.timeToPeakHours * 3600)
    }

    /// Dichotomie à la minute près sur une fonction croissante : dernier instant de `range` où `value < limit`.
    /// Précondition : `value(lowerBound) < limit` et `value(upperBound) >= limit`.
    private static func lastMinute(below limit: Double, in range: ClosedRange<Date>, value: (Date) -> Double) -> Date {
        var low = range.lowerBound
        var high = range.upperBound
        while high.timeIntervalSince(low) > 60 {
            let mid = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
            if value(mid) < limit { low = mid } else { high = mid }
        }
        return low
    }
}
