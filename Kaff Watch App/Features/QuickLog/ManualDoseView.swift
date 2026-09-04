import KaffCore
import SwiftUI
import WatchKit

/// Dose manuelle : cadran mg (crans de 5 mg) entouré du même anneau que Home, équivalence espresso, aperçu, Ajouter.
struct ManualDoseView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var dialFocused: Bool

    /// Dose en crans de `Theme.Dial.milligramsStep` (1 unité = 1 cran haptique).
    @State private var mgUnits = Theme.Dial.defaultMilligrams / Theme.Dial.milligramsStep
    /// Aperçu recalculé à chaque cran (pas à chaque rendu), comme la courbe de Home.
    @State private var preview: ImpactPreviewData?

    /// Arrondi au cran : la couronne livre des valeurs intermédiaires pendant la rotation.
    private var milligrams: Double { mgUnits.rounded() * Theme.Dial.milligramsStep }
    private var unitRange: ClosedRange<Double> {
        (Theme.Dial.milligramsRange.lowerBound / Theme.Dial.milligramsStep)...(Theme.Dial.milligramsRange.upperBound / Theme.Dial.milligramsStep)
    }
    private var ringSize: Double { min(WKInterfaceDevice.current().screenBounds.width * 0.31, 64) }
    /// La molette règle une quantité ingérée : on la rapporte à la dose unique max (ingérée), pas à la limite de pic.
    private var limitMg: Double { max(model.profile.singleDoseLimitMg, 1) }
    private var espresso: Drink? { DrinkCatalog.drink(id: "espresso", custom: []) }
    private var espressoCount: Double { espresso.map { DrinkEquivalence.count(of: $0, forMilligrams: milligrams) } ?? 0 }
    private var status: LevelStatus { LevelStatus(ratio: milligrams / limitMg, elevatedAt: LevelAssessor.elevatedPeakFraction) }

    var body: some View {
        ScrollView {
            VStack(spacing: 3) {
                HStack(spacing: 8) {
                    dial
                    equivalence
                }
                if let preview { ImpactPreviewView(data: preview) }
                AddDoseButton {
                    await model.log(milligrams: milligrams, drink: nil, volumeML: nil)
                    return model.lastError == nil
                } onSuccess: {
                    model.path = []
                }
                .padding(.top, 1)
            }
            .padding(.horizontal, 2)
        }
        .navigationTitle("Dose")
        .onChange(of: milligrams, initial: true) { _, mg in preview = ImpactPreviewData(model: model, adding: mg) }
        .onAppear { dialFocused = true }
        // Sans cela, la couronne reste attachée au cadran disparu et ne défile plus Home après le retour.
        .onDisappear { dialFocused = false }
    }

    private var dial: some View {
        ZStack {
            KaffRingView(progress: min(milligrams / limitMg, 1), overflowProgress: max(milligrams / limitMg - 1, 0),
                         tint: status.color, lineWidth: Theme.Ring.lineWidth * 0.75)
                .frame(width: ringSize, height: ringSize)
            VStack(spacing: -3) {
                Text(Formatters.mgValue(milligrams))
                    .font(Theme.Typography.dialInRing)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText(value: milligrams))
                Text("mg")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: ringSize - Theme.Ring.lineWidth * 2.5)
        }
        .frame(height: ringSize)
        .animation(Motion.crown(reduceMotion: reduceMotion), value: milligrams)
        .focusable()
        .focused($dialFocused)
        .digitalCrownRotation($mgUnits, from: unitRange.lowerBound, through: unitRange.upperBound, by: 1,
                              sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dose")
        .accessibilityValue("\(Formatters.mg(milligrams)), \(status.accessibilityLabel) pour une dose unique")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: mgUnits = min(mgUnits + 1, unitRange.upperBound)
            case .decrement: mgUnits = max(mgUnits - 1, unitRange.lowerBound)
            @unknown default: break
            }
        }
    }

    /// « ≈ 2,4 espressos » + rangée de tasses (arrondie à l'unité, max 5 puis « +n »), à droite de l'anneau.
    private var equivalence: some View {
        let cups = Int(espressoCount.rounded())
        let shown = min(cups, Theme.Dial.maxCups)
        return VStack(alignment: .leading, spacing: 3) {
            Text("≈ \(Formatters.count(espressoCount)) espresso\(Formatters.isPlural(espressoCount) ? "s" : "")")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())
            HStack(spacing: 2) {
                ForEach(0..<shown, id: \.self) { _ in
                    Image(systemName: "cup.and.saucer.fill")
                }
                if cups > shown {
                    Text("+\(cups - shown)").monospacedDigit()
                }
            }
            .font(.caption2)
            .foregroundStyle(Theme.accent)
            .frame(height: 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .animation(Motion.crown(reduceMotion: reduceMotion), value: cups)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Environ \(Formatters.count(espressoCount)) espressos")
    }
}
