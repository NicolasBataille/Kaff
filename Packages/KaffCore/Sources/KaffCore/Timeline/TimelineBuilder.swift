import Foundation

/// Échantillonne la courbe pour le graphique et calcule les instants d'entrée du widget.
public struct TimelineBuilder: Sendable {
    public static let widgetHours = 12.0
    public static let widgetStepMinutes = 15

    public let assessor: LevelAssessor

    public init(assessor: LevelAssessor) {
        self.assessor = assessor
    }

    public func chartPoints(doses: [CaffeineDose], from start: Date, hours: Double, stepMinutes: Int) -> [TimelinePoint] {
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
        let step = TimeInterval(stepMinutes * 60)
        let end = now.addingTimeInterval(hours * 3600)
        let grid = stride(from: 0.0, through: hours * 3600, by: step).map { now.addingTimeInterval($0) }
        var transitions: [Date] = []
        var previous = signature(doses: doses, at: now)
        var t = now.addingTimeInterval(60)
        while t <= end {
            let current = signature(doses: doses, at: t)
            if current != previous { transitions.append(t) }
            previous = current
            t = t.addingTimeInterval(60)
        }
        return Array(Set(grid + transitions)).sorted()
    }

    /// Comparaison de tuples : fournie par la bibliothèque standard, ne pas redéfinir `!=`.
    private func signature(doses: [CaffeineDose], at date: Date) -> (LevelStatus, Bool) {
        let a = assessor.assess(doses: doses, at: date)
        return (a.status, a.isSleepReady)
    }
}
