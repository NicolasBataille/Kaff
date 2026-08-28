import Foundation

/// Transforme un snapshot en liste d'entrées de complication (grille 15 min + transitions).
public enum WidgetTimelinePlanner {
    /// Sparkline 6 h de la famille rectangulaire : 24 échantillons espacés de 15 min.
    /// Source: choix produit (brief §4) ; la largeur d'une complication rectangulaire ne justifie pas plus de points.
    public static let sparklineSamples = 24
    public static let sparklineStepMinutes = 15

    public static func entries(snapshot: CacheSnapshot?, now: Date, calendar: Calendar = .current) -> [WidgetEntryData] {
        guard let snapshot else { return [.empty(at: now)] }
        let assessor = LevelAssessor(profile: snapshot.profile, calendar: calendar)
        // Même hypothèse que `widgetEntryDates` : seules les doses connues à `now` comptent sur tout l'horizon.
        let doses = snapshot.doses.filter { $0.date <= now }
        let dates = TimelineBuilder(assessor: assessor).widgetEntryDates(doses: doses, from: now)
        return dates.map { date in
            let a = assessor.assess(doses: doses, at: date)
            return WidgetEntryData(date: date, milligrams: a.currentMg, status: a.status,
                                   limitMg: snapshot.profile.singleDoseLimitMg,
                                   sleepReadyAt: a.sleepReadyAt, isSleepReady: a.isSleepReady, hasData: true,
                                   sparkline: sparkline(doses: doses, from: date, model: assessor.model))
        }
    }

    /// Niveaux bruts (sans évaluation de statut) : `amount` renvoie 0 pour une dose postérieure à l'instant échantillonné,
    /// donc les doses futures ne contribuent pas.
    static func sparkline(doses: [CaffeineDose], from start: Date, model: PharmacokineticModel) -> [Double] {
        let step = TimeInterval(sparklineStepMinutes * 60)
        return (0..<sparklineSamples).map { i in
            model.amount(doses: doses, at: start.addingTimeInterval(Double(i) * step))
        }
    }
}
