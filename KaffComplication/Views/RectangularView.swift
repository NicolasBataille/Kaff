import Charts
import KaffCore
import SwiftUI
import WidgetKit

/// Mini-anneau + « 142 mg · OK » (ou « 3,1 mg/L · OK ») + « Sommeil 05:12 » (« Ouvrir Kaff » si obsolète)
/// + sparkline 6 h (brief §4). Pas de grain sur le mini-anneau : bruit à 34 pt.
struct RectangularView: View {
    let data: WidgetEntryData

    @Environment(\.widgetRenderingMode) private var renderingMode

    private var ringSize: Double { Theme.Ring.miniComplicationSize }

    var body: some View {
        HStack(spacing: 6) {
            KaffRingView(progress: data.ringProgress, overflowProgress: data.ringOverflow,
                         tint: data.tint, lineWidth: Theme.Ring.miniLineWidth, isAnimated: false)
                .frame(width: ringSize, height: ringSize)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 1) {
                if data.hasData {
                    headline
                    Text(data.secondaryText)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(secondaryStyle)
                        .lineLimit(1)
                    Sparkline(values: data.sparkline, limitMg: data.limitMg, tint: data.tint)
                        .frame(height: Theme.Chart.sparklineHeight)
                        .widgetAccentable()
                } else {
                    Text(WidgetEntryData.openAppLabel)
                        .font(Theme.Typography.complication)
                    Text("Aucune donnée")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(data.accessibilityText)
    }

    /// Teinte sommeil en couleur ; gris sur cadran teinté ou quand la ligne dit « Ouvrir Kaff » (snapshot obsolète).
    private var secondaryStyle: AnyShapeStyle {
        renderingMode == .accented || data.isStale ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.sleep)
    }

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(verbatim: data.valueWithUnit)
                .font(Theme.Typography.complication)
                .monospacedDigit()
            Text("· \(data.status.label)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(data.tint)
                .widgetAccentable()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

/// Courbe 6 h à partir de l'entrée, `LineMark` seul, axes cachés. Le domaine suit la courbe comme sur Home.
private struct Sparkline: View {
    let values: [Double]
    let limitMg: Double
    let tint: Color

    private var yMax: Double { max((values.max() ?? 0) * 1.2, limitMg / 2, 1) }

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { index, value in
            LineMark(x: .value("Pas", index), y: .value("mg", value))
                .interpolationMethod(.monotone)
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...yMax)
        .chartLegend(.hidden)
    }
}
