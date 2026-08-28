import SwiftUI

/// Cadran couronne réutilisable : valeur héros, crans haptiques (1 unité = `step`), ligne explicative optionnelle.
/// Ne contient aucune logique métier : lit et écrit un `Binding<Double>`.
struct ValueDialView: View {
    let title: String
    let symbol: String
    let tint: Color
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String
    var footnote: ((Double) -> String)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var dialFocused: Bool
    @State private var units = 0.0
    @State private var isLoaded = false

    private var unitRange: ClosedRange<Double> { (range.lowerBound / step)...(range.upperBound / step) }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(format(value))
                .font(Theme.Typography.hero)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Theme.Typography.heroMinimumScale)
                .contentTransition(.numericText(value: value))
                .animation(Motion.crown(reduceMotion: reduceMotion), value: value)
            if let footnote {
                Text(footnote(value))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .contentTransition(.numericText())
                    .animation(Motion.crown(reduceMotion: reduceMotion), value: value)
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .focused($dialFocused)
        .digitalCrownRotation($units, from: unitRange.lowerBound, through: unitRange.upperBound, by: 1,
                              sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .navigationTitle(title)
        .onAppear {
            units = (value / step).rounded()
            isLoaded = true
            dialFocused = true
        }
        // Sans cela, la couronne reste attachée au cadran disparu et ne défile plus l'écran parent.
        .onDisappear { dialFocused = false }
        .onChange(of: units) { _, new in
            guard isLoaded else { return }
            // La couronne livre des valeurs intermédiaires entre deux crans : on arrondit au cran.
            let candidate = min(max(new.rounded() * step, range.lowerBound), range.upperBound)
            if candidate != value { value = candidate }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: units = min(units + 1, unitRange.upperBound)
            case .decrement: units = max(units - 1, unitRange.lowerBound)
            @unknown default: break
            }
        }
    }
}
