import Charts
import KaffCore
import SwiftUI

/// Données de l'aperçu d'impact, calculées par `AppModel` (pur) ; la vue ne fait que dessiner.
struct ImpactPreviewData: Equatable {
    let before: [TimelinePoint]
    let after: [TimelinePoint]
    let peakDate: Date
    let peakMg: Double
    let bedtimeMg: Double
    let status: LevelStatus
    let reason: LevelReason
    let limitMg: Double

    @MainActor
    static func make(model: AppModel, adding milligrams: Double, now: Date = .now) -> ImpactPreviewData {
        let peak = model.peak(afterAdding: milligrams)
        let atPeak = model.preview(adding: milligrams, at: peak.date)
        return ImpactPreviewData(
            before: model.chartPoints(from: now, hours: Theme.Chart.previewHours, stepMinutes: Theme.Chart.stepMinutes),
            after: model.chartPoints(from: now, hours: Theme.Chart.previewHours, stepMinutes: Theme.Chart.stepMinutes,
                                     adding: milligrams),
            peakDate: peak.date, peakMg: peak.mg,
            bedtimeMg: atPeak.projectedBedtimeMg,
            status: atPeak.status, reason: atPeak.reason,
            limitMg: model.profile.singleDoseLimitMg)
    }
}

/// Mini-courbe 6 h « avant / après » + « Pic 148 mg à 14:35 · coucher 61 mg » (brief §3.3).
struct ImpactPreviewView: View {
    let data: ImpactPreviewData

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var yMax: Double { max((data.after.map(\.milligrams).max() ?? 0) * 1.2, data.limitMg / 2, 1) }
    private var isHigh: Bool { data.status == .high }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            chart
                .frame(height: Theme.Chart.previewHeight)
            Text("Pic \(Formatters.mg(data.peakMg)) à \(Formatters.time(data.peakDate)) · coucher \(Formatters.mg(data.bedtimeMg))")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.75)
                .contentTransition(.numericText())
            // Ligne réservée (hauteur fixe) pour que le bouton Ajouter ne bouge pas quand l'alerte apparaît.
            Label(data.reason.label(for: data.status), systemImage: data.status.symbol)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(data.status.color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: 14)
                .opacity(data.status == .ok ? 0 : 1)
        }
        .animation(Motion.crown(reduceMotion: reduceMotion), value: data)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var chart: some View {
        Chart {
            ForEach(data.after) { point in
                AreaMark(x: .value("Heure", point.date), y: .value("mg", point.milligrams), series: .value("Série", "après"))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.linearGradient(colors: [lineColor.opacity(0.35), lineColor.opacity(0.02)],
                                                     startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Heure", point.date), y: .value("mg", point.milligrams), series: .value("Série", "après"))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(lineColor)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
            ForEach(data.before) { point in
                LineMark(x: .value("Heure", point.date), y: .value("mg", point.milligrams), series: .value("Série", "avant"))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.secondary.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, lineCap: .round))
            }
            if data.limitMg <= yMax {
                RuleMark(y: .value("Limite", data.limitMg))
                    .foregroundStyle(Theme.Status.high.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
            PointMark(x: .value("Pic", data.peakDate), y: .value("mg", data.peakMg))
                .symbolSize(28)
                .foregroundStyle(lineColor)
        }
        .chartYScale(domain: 0...yMax)
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
    }

    private var lineColor: Color { isHigh ? Theme.Status.high : Theme.accent }

    private var accessibilityText: String {
        var text = "Aperçu : pic \(Formatters.mg(data.peakMg)) à \(Formatters.time(data.peakDate)), \(Formatters.mg(data.bedtimeMg)) au coucher"
        if data.status != .ok { text += ", \(data.reason.label(for: data.status))" }
        return text
    }
}
