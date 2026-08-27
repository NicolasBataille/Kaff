/// Boissons prédéfinies. Valeurs : USDA FoodData Central et EFSA (2015), arrondies.
public enum DrinkCatalog {
    public static let builtIn: [Drink] = [
        Drink(id: "espresso", name: "Espresso", milligrams: 63, volumeML: 30, symbol: "cup.and.saucer.fill"),          // Source: USDA 212 mg/100 g
        Drink(id: "double-espresso", name: "Double espresso", milligrams: 125, volumeML: 60, symbol: "cup.and.saucer.fill"),
        Drink(id: "lungo", name: "Allongé", milligrams: 80, volumeML: 120, symbol: "cup.and.saucer.fill"),              // Source: estimation, entre espresso et filtre
        Drink(id: "filter", name: "Café filtre", milligrams: 95, volumeML: 240, symbol: "mug.fill"),                    // Source: USDA 40 mg/100 g
        Drink(id: "latte", name: "Latte / cappuccino", milligrams: 63, volumeML: 240, symbol: "mug.fill"),               // Source: 1 shot d'espresso
        Drink(id: "decaf", name: "Décaféiné", milligrams: 3, volumeML: 30, symbol: "cup.and.saucer"),                   // Source: USDA décaf espresso ~3 mg/30 ml
        Drink(id: "tea-black", name: "Thé noir", milligrams: 47, volumeML: 240, symbol: "leaf.fill"),                   // Source: USDA 20 mg/100 g
        Drink(id: "tea-green", name: "Thé vert", milligrams: 28, volumeML: 240, symbol: "leaf.fill"),                   // Source: USDA 12 mg/100 g
        Drink(id: "mate", name: "Maté", milligrams: 85, volumeML: 240, symbol: "leaf.fill"),                            // Source: EFSA 2015, ~35 mg/100 ml
        Drink(id: "cola", name: "Cola", milligrams: 34, volumeML: 355, symbol: "takeoutbag.and.cup.and.straw.fill"),    // Source: USDA 9,7 mg/100 g
        Drink(id: "energy", name: "Boisson énergisante", milligrams: 80, volumeML: 250, symbol: "bolt.fill"),           // Source: EFSA 2015, 32 mg/100 ml
        Drink(id: "dark-chocolate", name: "Chocolat noir", milligrams: 12, volumeML: 30, symbol: "square.fill"),        // Source: USDA ~43 mg/100 g ; volumeML = grammes ici
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
