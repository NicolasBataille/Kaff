import KaffCore
import SwiftUI
import WidgetKit

/// Anneau de Home à l'échelle de la complication, nombre au centre, « mg » logé dans l'ouverture basse de l'arc.
/// En mode `.accented` l'anneau prend la teinte du cadran : piste et dégradé restent lisibles par leurs opacités.
struct CircularView: View {
    let data: WidgetEntryData

    @Environment(\.widgetRenderingMode) private var renderingMode

    private var lineWidth: Double { Theme.Ring.complicationLineWidth }

    var body: some View {
        ZStack {
            KaffRingView(progress: data.ringProgress, overflowProgress: data.ringOverflow,
                         tint: data.tint, lineWidth: lineWidth, isAnimated: false)
                .widgetAccentable()
            Text(data.valueText)
                .font(Theme.Typography.complication)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, lineWidth * 2)
            Text("mg")
                .font(Theme.Typography.complicationUnit)
                .foregroundStyle(renderingMode == .accented ? .primary : .secondary)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, -1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(data.accessibilityText)
    }
}
