import Charts
import KaffCore
import SwiftUI

/// Courbe 12 h passées + 6 h projetées : aire dégradée accent, projection en pointillés,
/// ligne « maintenant », ligne limite, curseur de scrub optionnel.
struct CaffeineChartView: View {
    let points: [TimelinePoint]
    let now: Date
    let limitMg: Double
    var cursor: (date: Date, milligrams: Double, tint: Color)?

    private var past: [TimelinePoint] { points.filter { $0.date <= now } }
    private var future: [TimelinePoint] { points.filter { $0.date >= now } }
    /// Le domaine suit la courbe ; la ligne limite n'apparaît que lorsqu'elle est à portée (pic ≥ ~40 % de la limite),
    /// sinon un niveau bas serait écrasé en bas du graphique.
    private var yMax: Double { max((points.map(\.milligrams).max() ?? 0) * 1.2, limitMg / 2, 1) }
    private var showsLimit: Bool { limitMg <= yMax }

    var body: some View {
        Chart {
            ForEach(past) { point in
                AreaMark(x: .value("Heure", point.date), y: .value("mg", point.milligrams), series: .value("Série", "passé"))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.linearGradient(colors: [Theme.accent.opacity(0.45), Theme.accent.opacity(0.02)],
                                                     startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Heure", point.date), y: .value("mg", point.milligrams), series: .value("Série", "passé"))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
            ForEach(future) { point in
                LineMark(x: .value("Heure", point.date), y: .value("mg", point.milligrams), series: .value("Série", "projection"))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 3]))
            }
            if showsLimit {
                RuleMark(y: .value("Limite", limitMg))
                    .foregroundStyle(Theme.Status.high.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
            RuleMark(x: .value("Maintenant", now))
                .foregroundStyle(.secondary.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1))
            if let cursor {
                RuleMark(x: .value("Curseur", cursor.date))
                    .foregroundStyle(cursor.tint)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                PointMark(x: .value("Curseur", cursor.date), y: .value("mg", cursor.milligrams))
                    .symbolSize(40)
                    .foregroundStyle(cursor.tint)
            }
        }
        .chartYScale(domain: 0...yMax)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel(format: .dateTime.hour(), collisionResolution: .greedy)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityLabel("Courbe de caféine, 12 heures passées et 6 heures projetées")
    }
}
