import SwiftUI
import WidgetKit

@main
struct KaffComplicationBundle: WidgetBundle {
    var body: some Widget {
        PlaceholderWidget()
    }
}

struct PlaceholderEntry: TimelineEntry { let date: Date }

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry { .init(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) { completion(.init(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [.init(date: .now)], policy: .never))
    }
}

struct PlaceholderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "fr.batum.kaff.level", provider: PlaceholderProvider()) { _ in
            Text("☕").containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Caféine")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}
