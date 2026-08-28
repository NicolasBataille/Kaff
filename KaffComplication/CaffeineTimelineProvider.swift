import KaffCore
import OSLog
import WidgetKit

/// Lit le snapshot de l'App Group (jamais HealthKit, règle CLAUDE.md §4) et le déroule en entrées précalculées.
struct CaffeineTimelineProvider: TimelineProvider {
    private static let logger = Logger(subsystem: "fr.batum.kaff", category: "Widget")

    private var snapshot: CacheSnapshot? {
        AppGroup.defaults.flatMap { CacheStore(defaults: $0).read() }
    }

    /// Galerie de complications : une dose plausible pour que l'anneau et la courbe soient parlants.
    func placeholder(in context: Context) -> CaffeineEntry {
        let now = Date.now
        let sample = CacheSnapshot(doses: [CaffeineDose(date: now.addingTimeInterval(-45 * 60), milligrams: 130)],
                                   profile: .default, updatedAt: now)
        let first = WidgetTimelinePlanner.entries(snapshot: sample, now: now).first ?? .empty(at: now)
        return CaffeineEntry(data: first)
    }

    func getSnapshot(in context: Context, completion: @escaping (CaffeineEntry) -> Void) {
        guard !context.isPreview else { return completion(placeholder(in: context)) }
        let now = Date.now
        let first = WidgetTimelinePlanner.entries(snapshot: snapshot, now: now).first ?? .empty(at: now)
        completion(CaffeineEntry(data: first))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CaffeineEntry>) -> Void) {
        let now = Date.now
        let entries = WidgetTimelinePlanner.entries(snapshot: snapshot, now: now).map(CaffeineEntry.init)
        Self.log(entries, family: context.family)
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private static func log(_ entries: [CaffeineEntry], family: WidgetFamily) {
        guard let first = entries.first, let last = entries.last else { return }
        let transitions = entries.filter { Int($0.date.timeIntervalSince(first.date)) % 900 != 0 }
        logger.info("""
            timeline \(String(describing: family), privacy: .public): \(entries.count) entrées, \
            \(first.data.hasData ? "données" : "sans snapshot", privacy: .public), \
            de \(first.date.formatted(date: .omitted, time: .shortened), privacy: .public) \
            (\(Int(first.data.milligrams)) mg \(String(describing: first.data.status), privacy: .public)) \
            à \(last.date.formatted(date: .omitted, time: .shortened), privacy: .public) \
            (\(Int(last.data.milligrams)) mg), transitions : \
            \(transitions.map { "\($0.date.formatted(date: .omitted, time: .shortened)) → \(String(describing: $0.data.status))\($0.data.isSleepReady ? " sommeil OK" : "")" }.joined(separator: ", "), privacy: .public)
            """)
    }
}
