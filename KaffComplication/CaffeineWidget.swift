import KaffCore
import SwiftUI
import WidgetKit

/// Complication « Caféine » : anneau et jetons partagés avec l'app (`KaffUI`), timeline précalculée, tap → `kaff://log`.
struct CaffeineWidget: Widget {
    static let kind = "fr.batum.kaff.level"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CaffeineTimelineProvider()) { entry in
            CaffeineWidgetView(data: entry.data)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "kaff://log"))
        }
        .configurationDisplayName("Caféine")
        .description("Niveau de caféine estimé, mis à jour toutes les 15 minutes.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}

struct CaffeineWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let data: WidgetEntryData

    var body: some View {
        switch family {
        case .accessoryCircular: CircularView(data: data)
        case .accessoryRectangular: RectangularView(data: data)
        case .accessoryCorner: CornerView(data: data)
        default: InlineView(data: data)
        }
    }
}

#if DEBUG
extension CaffeineEntry {
    static func sample(hoursAgo: Double = 1, milligrams: Double = 180) -> CaffeineEntry {
        let now = Date.now
        let snapshot = CacheSnapshot(doses: [CaffeineDose(date: now.addingTimeInterval(-hoursAgo * 3600), milligrams: milligrams)],
                                     limits: AssessmentLimits(profile: .default), updatedAt: now)
        return CaffeineEntry(data: WidgetTimelinePlanner.entries(snapshot: snapshot, now: now).first!)
    }

    static let empty = CaffeineEntry(data: .empty(at: .now))
}

#Preview("Circulaire", as: .accessoryCircular) { CaffeineWidget() } timeline: {
    CaffeineEntry.sample(); CaffeineEntry.sample(milligrams: 320); CaffeineEntry.empty
}
#Preview("Rectangulaire", as: .accessoryRectangular) { CaffeineWidget() } timeline: {
    CaffeineEntry.sample(); CaffeineEntry.sample(hoursAgo: 6, milligrams: 90); CaffeineEntry.empty
}
#Preview("Coin", as: .accessoryCorner) { CaffeineWidget() } timeline: { CaffeineEntry.sample(); CaffeineEntry.empty }
#Preview("Ligne", as: .accessoryInline) { CaffeineWidget() } timeline: { CaffeineEntry.sample(); CaffeineEntry.empty }
#endif
