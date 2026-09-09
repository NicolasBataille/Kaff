import Foundation

/// Transforme un snapshot en liste d'entrées de complication (grille 15 min + transitions).
public enum WidgetTimelinePlanner {
    /// Sparkline 6 h de la famille rectangulaire : 24 échantillons espacés de 15 min.
    /// Source: choix produit (brief §4) ; la largeur d'une complication rectangulaire ne justifie pas plus de points.
    public static let sparklineSamples = 24
    public static let sparklineStepMinutes = 15

    /// L'obsolescence (`isStale`) est évaluée à la date de chaque entrée, la timeline étant précalculée : une entrée
    /// à +6 h peut être obsolète alors que la première ne l'est pas. Aucune entrée n'est insérée à l'instant exact
    /// du basculement (choix produit : la grille de 15 min suffit pour un indicateur discret).
    public static func entries(snapshot: CacheSnapshot?, now: Date, calendar: Calendar = .current) -> [WidgetEntryData] {
        guard let snapshot else { return [.empty(at: now)] }
        let assessor = LevelAssessor(limits: snapshot.limits, calendar: calendar)
        // Même hypothèse que `widgetEntryDates` : seules les doses connues à `now` comptent sur tout l'horizon.
        let doses = snapshot.doses.filter { $0.date <= now }
        let dates = TimelineBuilder(assessor: assessor).widgetEntryDates(doses: doses, from: now)
        return dates.map { entry(at: $0, doses: doses, assessor: assessor, snapshot: snapshot) }
    }

    /// L'entrée à `now` seule (une évaluation + sparkline, sans balayage 12 h) : placeholder et snapshot du widget.
    /// Strictement égale à `entries(snapshot:now:calendar:).first`.
    public static func firstEntry(snapshot: CacheSnapshot?, now: Date, calendar: Calendar = .current) -> WidgetEntryData {
        guard let snapshot else { return .empty(at: now) }
        let assessor = LevelAssessor(limits: snapshot.limits, calendar: calendar)
        return entry(at: now, doses: snapshot.doses.filter { $0.date <= now }, assessor: assessor, snapshot: snapshot)
    }

    /// Vrai quand, à `date`, le snapshot est strictement plus vieux que sa fenêtre de doses (spec §8, obsolescence).
    static func isStale(_ snapshot: CacheSnapshot, at date: Date) -> Bool {
        date.timeIntervalSince(snapshot.updatedAt) > snapshot.windowHours * 3600
    }

    private static func entry(at date: Date, doses: [CaffeineDose], assessor: LevelAssessor,
                              snapshot: CacheSnapshot) -> WidgetEntryData {
        let a = assessor.assess(doses: doses, at: date)
        return WidgetEntryData(date: date, milligrams: a.currentMg, status: a.status,
                               limitMg: snapshot.limits.peakLimitMg,
                               sleepReadyAt: a.sleepReadyAt, isSleepReady: a.isSleepReady, hasData: true,
                               sparkline: sparkline(doses: doses, from: date, model: assessor.model),
                               isStale: isStale(snapshot, at: date))
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
