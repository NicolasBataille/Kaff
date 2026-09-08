import SwiftUI

/// Badge « Poids estimé » (spec §9) : même look partout — sous la courbe de Home (avec le poids de repli),
/// à côté de chaque concentration dans la feuille de statut, sous la note de Réglages › Affichage.
/// Le conteneur décide de la navigation (lien vers les Réglages, ou rien quand on y est déjà).
struct EstimatedWeightLabel: View {
    var weightKg: Double? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Label {
            if let weightKg {
                Text("Poids estimé (\(Formatters.kg(weightKg)))")
            } else {
                Text("Poids estimé")
            }
        } icon: {
            Image(systemName: "scalemass")
        }
        .font(.caption2)
        .foregroundStyle(Theme.Status.elevated)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
        .minimumScaleFactor(0.8)
    }
}
