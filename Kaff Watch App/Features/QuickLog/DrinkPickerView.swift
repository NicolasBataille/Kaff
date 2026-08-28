import KaffCore
import SwiftUI

/// Sélecteur de boisson : carrousel (couronne = défilement natif), favoris en tête, tap → quantité avec morphing.
struct DrinkPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.zoomNamespace) private var zoom

    private var favorites: [Drink] { model.favoriteDrinks }
    private var others: [Drink] {
        let favoriteIDs = Set(favorites.map(\.id))
        return model.allDrinks.filter { !favoriteIDs.contains($0.id) }
    }

    var body: some View {
        List {
            ForEach(favorites) { drink in row(drink, isFavorite: true) }
            ForEach(others) { drink in row(drink, isFavorite: false) }
        }
        .listStyle(.carousel)
        .navigationTitle("Boisson")
    }

    private func row(_ drink: Drink, isFavorite: Bool) -> some View {
        NavigationLink(value: Route.amount(drink)) {
            DrinkCardView(drink: drink, isFavorite: isFavorite)
        }
        .zoomSource(id: Route.amount(drink), in: zoom)
        .accessibilityLabel("\(drink.name), \(drink.portionLabel)\(isFavorite ? ", favori" : "")")
    }
}

/// Carte : symbole dans un disque accent, nom, portion.
struct DrinkCardView: View {
    let drink: Drink
    let isFavorite: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.2))
                Image(systemName: drink.isCustom ? "mug.fill" : drink.symbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(drink.name)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    // Étoile masquée aux tailles d'accessibilité (le nom a besoin de toute la largeur ; les favoris restent en tête).
                    if isFavorite, !dynamicTypeSize.isAccessibilitySize {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.accent.opacity(0.8))
                    }
                }
                Text(drink.portionLabel)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
