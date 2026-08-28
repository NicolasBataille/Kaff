import KaffCore
import SwiftUI

/// Quantité d'une boisson : volume héros réglé à la couronne (crans de 10 ml), mg recalculés, aperçu d'impact, Ajouter.
struct DrinkAmountView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var dialFocused: Bool

    let drink: Drink
    /// Volume en crans de `Theme.Dial.volumeStep` (1 unité = 1 cran haptique).
    @State private var volumeUnits: Double
    /// Aperçu recalculé à chaque cran (pas à chaque rendu), comme la courbe de Home.
    @State private var preview: ImpactPreviewData?

    init(drink: Drink) {
        self.drink = drink
        _volumeUnits = State(initialValue: (drink.volumeML / Theme.Dial.volumeStep).rounded())
    }

    /// Arrondi au cran : la couronne livre des valeurs intermédiaires pendant la rotation.
    private var volumeML: Double { volumeUnits.rounded() * Theme.Dial.volumeStep }
    private var milligrams: Double { drink.milligrams(forVolumeML: volumeML) }
    private var unitRange: ClosedRange<Double> {
        (Theme.Dial.volumeRange.lowerBound / Theme.Dial.volumeStep)...(Theme.Dial.volumeRange.upperBound / Theme.Dial.volumeStep)
    }
    /// Disque du symbole, de la hauteur de la ligne « ≈ 63 mg ».
    private static let symbolSize = 20.0

    var body: some View {
        ScrollView {
            VStack(spacing: 3) {
                dial
                if let preview { ImpactPreviewView(data: preview) }
                AddDoseButton {
                    await model.log(milligrams: milligrams, drink: drink, volumeML: volumeML)
                    return model.lastError == nil
                } onSuccess: {
                    model.path = []
                }
                .padding(.top, 1)
            }
            .padding(.horizontal, 2)
        }
        .navigationTitle(drink.name)
        .onChange(of: milligrams, initial: true) { _, mg in preview = ImpactPreviewData(model: model, adding: mg) }
        .onAppear { dialFocused = true }
        // Sans cela, la couronne reste attachée au cadran disparu et ne défile plus Home après le retour.
        .onDisappear { dialFocused = false }
    }

    /// Volume héros + symbole de la boisson et « ≈ 63 mg » sur une ligne (le nom est le titre de navigation).
    private var dial: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(Int(volumeML.rounded()))")
                    .font(Theme.Typography.dial)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: volumeML))
                Text(drink.volumeUnit)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                DrinkSymbolDisc(drink: drink, size: Self.symbolSize)
                Text("≈ \(Formatters.mg(milligrams))")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText(value: milligrams))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(Theme.Typography.heroMinimumScale)
        .animation(Motion.crown(reduceMotion: reduceMotion), value: volumeML)
        .focusable()
        .focused($dialFocused)
        .digitalCrownRotation($volumeUnits, from: unitRange.lowerBound, through: unitRange.upperBound, by: 1,
                              sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Volume de \(drink.name)")
        .accessibilityValue("\(Int(volumeML.rounded())) \(drink.volumeUnit), soit \(Formatters.mg(milligrams))")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: volumeUnits = min(volumeUnits + 1, unitRange.upperBound)
            case .decrement: volumeUnits = max(volumeUnits - 1, unitRange.lowerBound)
            @unknown default: break
            }
        }
    }
}

extension ImpactPreviewData {
    @MainActor
    init(model: AppModel, adding milligrams: Double) {
        self = ImpactPreviewData.make(model: model, adding: milligrams)
    }
}
