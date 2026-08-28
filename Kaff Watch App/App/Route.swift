import KaffCore

/// Destinations de navigation de l'app (pile typée : `AppModel.path`).
enum Route: Hashable {
    case logDrink
    /// Quantité d'une boisson choisie dans le sélecteur.
    case amount(Drink)
    case logManual
    case settings
}
