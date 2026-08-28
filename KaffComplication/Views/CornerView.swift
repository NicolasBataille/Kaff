import KaffCore
import SwiftUI
import WidgetKit

/// Nombre dans le coin, jauge linéaire (courbée par le cadran) en `widgetLabel`, teinte de statut.
struct CornerView: View {
    let data: WidgetEntryData

    var body: some View {
        Text(data.valueText)
            .font(Theme.Typography.complication)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .widgetAccentable()
            .widgetLabel {
                Gauge(value: data.ringProgress, in: 0...1) {
                    Text("mg")
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(data.tint)
            }
            .accessibilityLabel(data.accessibilityText)
    }
}
