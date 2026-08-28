import KaffCore
import SwiftUI

/// Symbole SF d'une boisson dans un disque teinté accent (carrousel, historique, écran Quantité).
struct DrinkSymbolDisc: View {
    let symbol: String
    let size: Double

    init(drink: Drink?, size: Double) {
        symbol = drink.map(\.displaySymbol) ?? "number"
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle().fill(Theme.accent.opacity(0.2))
            Image(systemName: symbol)
                .font(.system(size: size / 2, weight: .medium))
                .foregroundStyle(Theme.accent)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
