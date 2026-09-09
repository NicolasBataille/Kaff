#if DEBUG
import KaffCore
import SwiftUI
import WidgetKit

/// Debug simulateur uniquement (`SIMCTL_CHILD_KAFF_WIDGET_GALLERY=1 xcrun simctl launch …`) : rend les vues des quatre
/// familles de complication avec le snapshot courant de l'App Group, aux dimensions approximatives d'un cadran 46 mm.
/// Le simulateur watchOS ne permet pas d'ajouter un cadran à complications (galerie inopérante) ; cette galerie
/// vérifie le rendu des vues, pas l'hébergement WidgetKit (`widgetLabel`, mode `.accented`, timeline).
/// v0.3 : approximation du mode teinté (environnement `.accented` + désaturation — l'hôte seul teinte réellement),
/// et le grain de café seul pour juger sa forme.
struct WidgetGalleryView: View {
    /// Source: HIG « Complications », 45/46 mm — valeurs arrondies, indicatives.
    private enum Size {
        static let circular = 50.0
        static let corner = 46.0
        static let rectangular = CGSize(width: 180, height: 58)
        static let heroRing = 96.0
        static let bean = 44.0
    }

    private struct Sample: Identifiable {
        let id: String
        let caption: String
        let data: WidgetEntryData
        var accented = false
    }

    private let samples: [Sample]

    init() {
        let snapshot = CacheStore(defaults: SharedDefaults.resolve()).read()
        let limits = snapshot?.limits ?? AssessmentLimits(profile: .default)
        let now = Date.now
        let live = WidgetTimelinePlanner.entries(snapshot: snapshot, now: now).first ?? .empty(at: now)
        // Entrées synthétiques (élevé, trop haut, obsolète, sans données) pour voir chaque teinte.
        func synthetic(_ mg: Double, hoursAgo: Double, updatedHoursAgo: Double = 0) -> WidgetEntryData {
            let s = CacheSnapshot(doses: [CaffeineDose(date: now.addingTimeInterval(-hoursAgo * 3600), milligrams: mg)],
                                  limits: limits,
                                  updatedAt: now.addingTimeInterval(-updatedHoursAgo * 3600))
            return WidgetTimelinePlanner.entries(snapshot: s, now: now).first!
        }
        samples = [
            Sample(id: "live", caption: "Snapshot", data: live),
            Sample(id: "elevated", caption: "Élevé", data: synthetic(160, hoursAgo: 1)),
            Sample(id: "high", caption: "Trop haut", data: synthetic(320, hoursAgo: 0.75)),
            // Obsolète : snapshot écrit il y a 31 h (fenêtre par défaut 30 h) → « Ouvrir Kaff » en ligne secondaire.
            Sample(id: "stale", caption: "Obsolète",
                   data: synthetic(160, hoursAgo: 1, updatedHoursAgo: CacheSnapshot.defaultWindowHours + 1)),
            Sample(id: "empty", caption: "Sans données", data: .empty(at: now)),
            Sample(id: "accented", caption: "Teinté (approximation)", data: synthetic(160, hoursAgo: 1), accented: true),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(samples) { sample in
                    caption(sample.caption)
                    if sample.accented {
                        families(sample.data)
                            .environment(\.widgetRenderingMode, .accented)
                            .saturation(0)
                    } else {
                        families(sample.data)
                    }
                }
                caption("Grain")
                beanRow
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Widgets")
    }

    private func caption(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private func families(_ data: WidgetEntryData) -> some View {
        VStack(spacing: 10) {
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

    /// Anneau taille héros avec le grain en filigrane, et le grain seul (opacité forcée) pour juger sa forme.
    private var beanRow: some View {
        HStack(spacing: 12) {
            KaffRingView(progress: 0.6, tint: Theme.Status.ok, isAnimated: false, showsBean: true)
                .frame(width: Size.heroRing, height: Size.heroRing)
            CoffeeBeanShape()
                .fill(Theme.accent, style: FillStyle(eoFill: true))
                .frame(width: Size.bean, height: Size.bean)
        }
    }

    private struct Container: ViewModifier {
        let shape: AnyShape
        func body(content: Content) -> some View {
            content.padding(4).background(.fill.tertiary, in: shape)
        }
    }
}
#endif
