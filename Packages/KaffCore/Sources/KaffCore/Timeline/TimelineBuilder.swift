import Foundation

/// Échantillonne la courbe pour le graphique et calcule les instants d'entrée du widget.
public struct TimelineBuilder: Sendable {
    /// Source: choix produit, spec §8.
    public static let widgetHours = 12.0
    /// Source: choix produit, spec §8.
    public static let widgetStepMinutes = 15

    public let assessor: LevelAssessor

    public init(assessor: LevelAssessor) {
        self.assessor = assessor
    }

    public func chartPoints(doses: [CaffeineDose], from start: Date, hours: Double, stepMinutes: Int) -> [TimelinePoint] {
        precondition(stepMinutes > 0, "stepMinutes doit être > 0")
        let step = TimeInterval(stepMinutes * 60)
        let count = Int(hours * 3600 / step)
        return (0...count).map { i in
            let date = start.addingTimeInterval(Double(i) * step)
            let a = assessor.assess(doses: doses, at: date)
            return TimelinePoint(date: date, milligrams: a.currentMg, status: a.status)
        }
    }

    /// Grille régulière + un instant à chaque changement de statut ou de « prêt pour dormir ».
    public func widgetEntryDates(doses: [CaffeineDose], from now: Date,
                                 hours: Double = widgetHours, stepMinutes: Int = widgetStepMinutes) -> [Date] {
        precondition(stepMinutes > 0, "stepMinutes doit être > 0")
        let step = TimeInterval(stepMinutes * 60)
        let end = now.addingTimeInterval(hours * 3600)
        let grid = stride(from: 0.0, through: hours * 3600, by: step).map { now.addingTimeInterval($0) }
        // Calculé une fois : la courbe est déterminée par les doses passées, indépendamment de l'instant d'échantillonnage.
        // Note (déviation, revue M1) : `assessor.sleepReadyDate` fait une recherche par dichotomie à la minute
        // près, précise à ±60 s. La comparer telle quelle à chaque point de la grille peut décaler la transition
        // détectée d'une minute par rapport à un test qui recalcule `assess(at:)` exactement à chaque instant.
        // On garde donc uniquement le pic (calcul immédiat, pas de dichotomie) et on compare le niveau courant
        // à la limite à chaque point : c'est équivalent à `assess(at:).isSleepReady` (mêmes seuils courts-circuités
        // dans `sleepReadyDate`) mais sans refaire une recherche complète à chaque minute.
        let lastPeak = doses.filter { $0.date <= now }.map(\.date).max()
            .map { $0.addingTimeInterval(assessor.model.timeToPeakHours * 3600) }
        let bedtimeLimitMg = assessor.profile.bedtimeLimitMg
        var transitions: [Date] = []
        var previous = signature(doses: doses, at: now, lastPeak: lastPeak, bedtimeLimitMg: bedtimeLimitMg)
        var t = now.addingTimeInterval(60)
        while t <= end {
            let current = signature(doses: doses, at: t, lastPeak: lastPeak, bedtimeLimitMg: bedtimeLimitMg)
            if current != previous { transitions.append(t) }
            previous = current
            t = t.addingTimeInterval(60)
        }
        return Array(Set(grid + transitions)).sorted()
    }

    /// Comparaison de tuples : fournie par la bibliothèque standard, ne pas redéfinir `!=`.
    /// `isSleepReady` : aucune dose (`lastPeak == nil`) → toujours prêt ; sinon prêt une fois le pic passé et
    /// le niveau courant sous la limite de coucher (équivalent exact du court-circuit de `sleepReadyDate`).
    private func signature(doses: [CaffeineDose], at date: Date, lastPeak: Date?, bedtimeLimitMg: Double) -> (LevelStatus, Bool) {
        let a = assessor.assess(doses: doses, at: date)
        guard let lastPeak else { return (a.status, true) }
        let isSleepReady = date >= lastPeak && assessor.model.amount(doses: doses.filter { $0.date <= date }, at: date) < bedtimeLimitMg
        return (a.status, isSleepReady)
    }
}
