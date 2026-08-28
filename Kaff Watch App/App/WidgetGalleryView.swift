#if DEBUG
import KaffCore
import SwiftUI

/// Debug simulateur uniquement (`SIMCTL_CHILD_KAFF_WIDGET_GALLERY=1 xcrun simctl launch …`) : rend les vues des quatre
/// familles de complication avec le snapshot courant de l'App Group, aux dimensions approximatives d'un cadran 46 mm.
/// Le simulateur watchOS ne permet pas d'ajouter un cadran à complications (galerie inopérante) ; cette galerie
/// vérifie le rendu des vues, pas l'hébergement WidgetKit (`widgetLabel`, mode `.accented`, timeline).
struct WidgetGalleryView: View {
    /// Source: HIG « Complications », 45/46 mm — valeurs arrondies, indicatives.
    private enum Size {
        static let circular = 50.0
        static let corner = 46.0
        static let rectangular = CGSize(width: 180, height: 58)
    }

    private let entries: [WidgetEntryData]

    init() {
        let snapshot = CacheStore(defaults: SharedDefaults.resolve()).read()
        let live = WidgetTimelinePlanner.entries(snapshot: snapshot, now: .now)
        // Entrée réelle + entrées synthétiques (élevé, trop haut, sans données) pour voir chaque teinte.
        let now = Date.now
        func synthetic(_ mg: Double, hoursAgo: Double) -> WidgetEntryData {
            let s = CacheSnapshot(doses: [CaffeineDose(date: now.addingTimeInterval(-hoursAgo * 3600), milligrams: mg)],
                                  profile: snapshot?.profile ?? .default, updatedAt: now)
            return WidgetTimelinePlanner.entries(snapshot: s, now: now).first!
        }
        entries = [live.first ?? .empty(at: now), synthetic(160, hoursAgo: 1), synthetic(320, hoursAgo: 0.75), .empty(at: now)]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, data in
                    HStack(spacing: 8) {
                        CircularView(data: data)
                            .frame(width: Size.circular, height: Size.circular)
                            .modifier(Container(shape: AnyShape(Circle())))
                        CornerView(data: data)
                            .frame(width: Size.corner, height: Size.corner)
                            .modifier(Container(shape: AnyShape(Circle())))
                    }
                    RectangularView(data: data)
                        .frame(width: Size.rectangular.width, height: Size.rectangular.height)
                        .modifier(Container(shape: AnyShape(RoundedRectangle(cornerRadius: 12))))
                    InlineView(data: data)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Widgets")
    }

    private struct Container: ViewModifier {
        let shape: AnyShape
        func body(content: Content) -> some View {
            content.padding(4).background(.fill.tertiary, in: shape)
        }
    }
}
#endif
