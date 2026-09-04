/// Boissons prédéfinies. Valeurs : USDA FoodData Central et EFSA (2015), arrondies.
/// Une tasse réelle varie du simple au sextuple (espresso 48–322 mg, Ludwig 2014).
public enum DrinkCatalog {
    public static let builtIn: [Drink] = [
        Drink(id: "espresso", name: "Espresso", milligrams: 63, volumeML: 30, symbol: "cup.and.saucer.fill"),          // Source: USDA 212 mg/100 g
        Drink(id: "double-espresso", name: "Double espresso", milligrams: 125, volumeML: 60, symbol: "cup.and.saucer.fill"),
        Drink(id: "lungo", name: "Allongé", milligrams: 80, volumeML: 120, symbol: "cup.and.saucer.fill"),              // Source: estimation — extraction longue +20–33 % vs espresso court (Ludwig 2014) : 63 × 1,25 ≈ 80 mg
        Drink(id: "filter", name: "Café filtre", milligrams: 95, volumeML: 240, symbol: "mug.fill"),                    // Source: USDA 40 mg/100 g
        Drink(id: "latte", name: "Latte / cappuccino", milligrams: 63, volumeML: 240, symbol: "mug.fill"),               // Source: 1 shot d'espresso
        Drink(id: "decaf", name: "Décaféiné", milligrams: 3, volumeML: 30, symbol: "cup.and.saucer"),                   // Source: USDA décaf espresso ~3 mg/30 ml
        Drink(id: "tea-black", name: "Thé noir", milligrams: 47, volumeML: 240, symbol: "leaf.fill"),                   // Source: USDA 20 mg/100 g
        Drink(id: "tea-green", name: "Thé vert", milligrams: 28, volumeML: 240, symbol: "leaf.fill"),                   // Source: USDA 12 mg/100 g
        Drink(id: "mate", name: "Maté", milligrams: 80, volumeML: 150, symbol: "leaf.fill"),                            // Source: Heck & de Mejia 2007, ≈ 78 mg par tasse de 150 ml ; très variable selon la préparation
        Drink(id: "cola", name: "Cola", milligrams: 32, volumeML: 330, symbol: "takeoutbag.and.cup.and.straw.fill"),    // Source: USDA 9,7 mg/100 g ; canette 33 cl
        Drink(id: "energy", name: "Boisson énergisante", milligrams: 80, volumeML: 250, symbol: "bolt.fill"),           // Source: EFSA 2015, 32 mg/100 ml
        Drink(id: "dark-chocolate", name: "Chocolat noir", milligrams: 24, volumeML: 30, symbol: "square.fill"),        // Source: USDA FDC 170273, chocolat noir 70–85 % cacao, 80 mg/100 g ; volumeML = grammes ici
    ]

    public static func drink(id: String, custom: [Drink]) -> Drink? {
        (builtIn + custom).first { $0.id == id }
    }

    /// Identifiants les plus fréquents, par ordre décroissant, égalités départagées par ordre d'apparition.
    public static func favoriteIDs(from loggedIDs: [String], limit: Int) -> [String] {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for id in loggedIDs {
            if counts[id] == nil { order.append(id) }
            counts[id, default: 0] += 1
        }
        let ranked = order.sorted { a, b in
            if counts[a]! != counts[b]! { return counts[a]! > counts[b]! }
            return order.firstIndex(of: a)! < order.firstIndex(of: b)!
        }
        return Array(ranked.prefix(limit))
    }
}
