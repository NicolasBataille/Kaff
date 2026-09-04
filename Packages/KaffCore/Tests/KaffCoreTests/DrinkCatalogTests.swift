import Testing
@testable import KaffCore

@Test func catalogHasUniqueIDsAndPositiveValues() {
    let ids = DrinkCatalog.builtIn.map(\.id)
    #expect(Set(ids).count == ids.count)
    #expect(DrinkCatalog.builtIn.allSatisfy { $0.milligrams >= 0 && $0.volumeML > 0 })
    #expect(DrinkCatalog.builtIn.count >= 10)
}

@Test func lookupByID() {
    #expect(DrinkCatalog.drink(id: "espresso", custom: [])?.milligrams == 63)
    let custom = Drink(id: "custom-1", name: "Mon thé", milligrams: 40, volumeML: 200, symbol: "leaf.fill", isCustom: true)
    #expect(DrinkCatalog.drink(id: "custom-1", custom: [custom])?.name == "Mon thé")
    #expect(DrinkCatalog.drink(id: "nope", custom: []) == nil)
}

/// Valeurs sourcées en M5.6 : chocolat noir 70–85 % cacao 80 mg/100 g (USDA FDC 170273) → 24 mg pour 30 g ;
/// maté ≈ 78 mg par tasse de 150 ml (Heck & de Mejia 2007) → 80 mg / 150 ml.
@Test func sourcedCatalogValuesForDarkChocolateAndMate() {
    let chocolate = DrinkCatalog.drink(id: "dark-chocolate", custom: [])
    #expect(chocolate?.milligrams == 24)
    #expect(chocolate?.volumeML == 30)
    let mate = DrinkCatalog.drink(id: "mate", custom: [])
    #expect(mate?.milligrams == 80)
    #expect(mate?.volumeML == 150)
}

@Test func equivalenceInEspressos() {
    let espresso = DrinkCatalog.drink(id: "espresso", custom: [])!
    #expect(abs(DrinkEquivalence.count(of: espresso, forMilligrams: 150) - 2.38) < 0.01)
    #expect(DrinkEquivalence.count(of: espresso, forMilligrams: 0) == 0)
}

@Test func favoritesAreMostFrequentDrinkIDs() {
    let ids = ["espresso", "tea-black", "espresso", "cola", "espresso", "tea-black", "mate"]
    #expect(DrinkCatalog.favoriteIDs(from: ids, limit: 2) == ["espresso", "tea-black"])
}
