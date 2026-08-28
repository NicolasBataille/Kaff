import KaffCore

extension Drink {
    /// Le chocolat noir est catalogué en grammes dans `volumeML` (note du catalogue KaffCore).
    var volumeUnit: String { id == "dark-chocolate" ? "g" : "ml" }

    /// Symbole affiché : les boissons personnalisées partagent `mug.fill`.
    var displaySymbol: String { isCustom ? "mug.fill" : symbol }

    /// « 63 mg · 30 ml »
    var portionLabel: String { "\(Formatters.mg(milligrams)) · \(Int(volumeML.rounded())) \(volumeUnit)" }
}
