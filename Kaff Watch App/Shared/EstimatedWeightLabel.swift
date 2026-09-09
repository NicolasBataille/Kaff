import SwiftUI

/// Badge « Poids estimé (70 kg) » (spec §9) sous la courbe de Home, avec le poids de repli.
/// Le conteneur décide de la navigation (lien vers les Réglages).
struct EstimatedWeightLabel: View {
    let weightKg: Double

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Label("Poids estimé (\(Formatters.kg(weightKg)))", systemImage: "scalemass")
        .font(.caption2)
        .foregroundStyle(Theme.Status.elevated)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
        .minimumScaleFactor(0.8)
    }
}
