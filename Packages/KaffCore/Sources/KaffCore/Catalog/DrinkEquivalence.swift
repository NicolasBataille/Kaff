/// Conversion mg ⇄ nombre de boissons (« 150 mg ≈ 2,4 espressos »).
public enum DrinkEquivalence {
    public static func count(of drink: Drink, forMilligrams mg: Double) -> Double {
        guard drink.milligrams > 0 else { return 0 }
        return mg / drink.milligrams
    }
}
