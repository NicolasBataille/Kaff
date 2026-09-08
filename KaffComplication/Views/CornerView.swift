import KaffCore
import SwiftUI
import WidgetKit

/// Nombre dans le coin (grain de café en filigrane derrière, v0.3), jauge linéaire (courbée par le cadran)
/// en `widgetLabel` avec l'unité, teinte de statut.
struct CornerView: View {
    let data: WidgetEntryData

    var body: some View {
        Text(data.valueText)
            .font(Theme.Typography.complication)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .background {
                CoffeeBeanShape()
                    .fill(data.tint.opacity(Theme.Ring.beanOpacity), style: FillStyle(eoFill: true))
                    .frame(width: Theme.Ring.cornerBeanSize, height: Theme.Ring.cornerBeanSize)
            }
            .widgetAccentable()
            .widgetLabel {
                Gauge(value: data.ringProgress, in: 0...1) {
                    Text(verbatim: data.unitLabel)
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(data.tint)
            }
            .accessibilityLabel(data.accessibilityText)
    }
}
