import KaffCore
import OSLog
import WidgetKit

/// Lit le snapshot de l'App Group (jamais HealthKit, règle CLAUDE.md §4) et le déroule en entrées précalculées.
struct CaffeineTimelineProvider: TimelineProvider {
    private static let logger = Logger(subsystem: "fr.nikou.kaff", category: "Widget")
    /// App Group absent = erreur de configuration : signalée par un `fault` unique, comme `SharedDefaults.resolve()` côté app.
    private static let appGroupFault: Void = {
        logger.fault("App Group indisponible côté complication")
    }()

    private var snapshot: CacheSnapshot? {
        guard let defaults = AppGroup.defaults else {
            _ = Self.appGroupFault
            return nil
        }
        return CacheStore(defaults: defaults).read()
    }

    /// Galerie de complications : une dose plausible pour que l'anneau et la courbe soient parlants.
    func placeholder(in context: Context) -> CaffeineEntry {
        let now = Date.now
        let sample = CacheSnapshot(doses: [CaffeineDose(date: now.addingTimeInterval(-45 * 60), milligrams: 130)],
                                   limits: AssessmentLimits(profile: .default), updatedAt: now)
        return CaffeineEntry(data: WidgetTimelinePlanner.firstEntry(snapshot: sample, now: now))
    }

    func getSnapshot(in context: Context, completion: @escaping (CaffeineEntry) -> Void) {
        guard !context.isPreview else { return completion(placeholder(in: context)) }
        completion(CaffeineEntry(data: WidgetTimelinePlanner.firstEntry(snapshot: snapshot, now: .now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CaffeineEntry>) -> Void) {
        let now = Date.now
        let entries = WidgetTimelinePlanner.entries(snapshot: snapshot, now: now).map(CaffeineEntry.init)
        Self.log(entries, family: context.family)
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// Diagnostic de la timeline (`log stream --predicate 'subsystem == "fr.nikou.kaff"'`), DEBUG seulement :
    /// les valeurs (mg, statut) restent privées, seule la famille est publique.
    private static func log(_ entries: [CaffeineEntry], family: WidgetFamily) {
        #if DEBUG
        guard let first = entries.first, let last = entries.last else { return }
        let transitions = entries.filter { Int($0.date.timeIntervalSince(first.date)) % 900 != 0 }
        let time = { (e: CaffeineEntry) in e.date.formatted(date: .omitted, time: .shortened) }
        let summary = """
            \(entries.count) entrées, \(first.data.hasData ? "données" : "sans snapshot"), \
            de \(time(first)) (\(Int(first.data.milligrams)) mg \(String(describing: first.data.status))) \
            à \(time(last)) (\(Int(last.data.milligrams)) mg), transitions : \
            \(transitions.map { "\(time($0)) → \(String(describing: $0.data.status))\($0.data.isSleepReady ? " sommeil OK" : "")" }.joined(separator: ", "))
            """
        logger.debug("timeline \(String(describing: family), privacy: .public): \(summary)")
        #endif
    }
}
