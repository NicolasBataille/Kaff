import KaffCore
import SwiftUI

/// Carte « Aujourd'hui 320 / 400 mg » avec jauge linéaire tintée par `dailyStatus`.
struct DailySummaryCard: View {
    let totalMg: Double
    let limitMg: Double
    let status: LevelStatus

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Libellé et valeur côte à côte ; empilés aux tailles d'accessibilité.
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                                                             : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            layout {
                Text("Aujourd'hui")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(Formatters.mgValue(totalMg))
                        .font(.title3.weight(.bold))
                        .contentTransition(.numericText(value: totalMg))
                    Text("/ \(Formatters.mg(limitMg))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(status.color)
            }
            Gauge(value: min(totalMg, limitMg), in: 0...max(limitMg, 1)) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(status.color)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(status.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(Motion.colour(reduceMotion: reduceMotion), value: status)
        .animation(Motion.snap(reduceMotion: reduceMotion), value: totalMg)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Aujourd'hui : \(Formatters.mg(totalMg)) sur \(Formatters.mg(limitMg)), \(status.accessibilityLabel)")
    }
}
