import SwiftUI

/// Jetons visuels (docs/design/ui-direction.md §2). Toute couleur ou dimension de l'UI vient d'ici.
enum Theme {
    /// Couleurs de statut (anneau, pastille, textes de statut).
    enum Status {
        static let ok = Color.mint
        static let elevated = Color.orange
        static let high = Color.red
    }

    /// Tout ce qui parle de coucher / sommeil.
    static let sleep = Color.indigo
    /// Café, boutons principaux, courbe passée.
    // Source: AccentColor #C8792B (asset absent de l'extension)
    static let accent = Color(red: 0xC8 / 255, green: 0x79 / 255, blue: 0x2B / 255)
    /// Anneau vide / état sans caféine.
    static let idle = Color.gray
    /// Glow radial derrière l'anneau (§2 : opacité 0,18).
    static let glowOpacity = 0.18

    enum Ring {
        /// Arc style anneaux Activité : 300°, ouverture centrée en bas.
        static let sweepDegrees = 300.0
        static let lineWidth = 9.0
        /// Seconde couche fine pour le dépassement de la limite.
        static let overflowLineWidth = 3.0
        static let trackOpacity = 0.16
        /// Complication circulaire (~45 pt) : mêmes proportions que Home (9 pt sur ~120 pt).
        static let complicationLineWidth = 4.0
        /// Mini-anneau de la complication rectangulaire.
        static let miniComplicationSize = 34.0
        static let miniLineWidth = 3.5
        /// Filigrane grain de café derrière l'anneau (spec §8, v0.3). Plage du brief 0,08–0,12 ; 0,10 validé sur la
        /// circulaire ≈ 50 pt (trois chiffres, proxy teinté désaturé, AX5) : le nombre reste lisible.
        static let beanOpacity = 0.10
        /// Retrait du grain à l'intérieur de la piste, en multiples de l'épaisseur du trait.
        static let beanInset = 1.6
        /// Grain derrière le nombre de la complication de coin (≈ 46 pt de côté, nombre en `.title3`).
        static let cornerBeanSize = 30.0
    }

    enum Typography {
        /// Nombre héros (mg sur Home, mg sur le cadran manuel).
        static let hero = Font.system(size: 44, weight: .bold, design: .rounded)
        static let heroCompact = Font.system(size: 34, weight: .bold, design: .rounded)
        static let dial = Font.system(size: 36, weight: .bold, design: .rounded)
        static let dialInRing = Font.system(size: 28, weight: .bold, design: .rounded)
        static let heroMinimumScale = 0.8
        /// Nombre des complications (circulaire, coin, titre rectangulaire).
        static let complication = Font.system(.title3, design: .rounded).weight(.bold)
        /// « mg » logé dans l'ouverture de l'anneau circulaire.
        static let complicationUnit = Font.system(size: 8, weight: .semibold, design: .rounded)
    }

    enum Chart {
        static let restingHeight = 64.0
        static let scrubbingHeight = 96.0
        static let previewHeight = 40.0
        static let pastHours = 12.0
        static let futureHours = 6.0
        static let stepMinutes = 10
        static let previewHours = 6.0
        /// Pas de l'aperçu d'impact : 6 h en 25 points suffisent à 40 pt de haut et divisent le coût par cran.
        static let previewStepMinutes = 15
        /// Sparkline de la complication rectangulaire.
        static let sparklineHeight = 14.0
    }

    enum Scrub {
        /// Bornes du scrubber couronne, en crans de `stepMinutes` autour de « maintenant » (−12 h … +6 h).
        static let stepMinutes = 15.0
        static let minSteps = -Chart.pastHours * 60 / stepMinutes
        static let maxSteps = Chart.futureHours * 60 / stepMinutes
        /// Sortie automatique du mode scrub après inactivité.
        static let idleExit: Duration = .milliseconds(1200)
    }

    enum Dial {
        static let volumeRange = 10.0...1000.0
        static let volumeStep = 10.0
        static let milligramsRange = 5.0...1000.0
        static let milligramsStep = 5.0
        static let defaultMilligrams = 80.0
        /// Tasses affichées au maximum sous le cadran mg (au-delà : « +n »).
        static let maxCups = 5
    }

    /// Délai entre la coche de confirmation et le retour à Home.
    static let confirmationDelay: Duration = .milliseconds(350)

    /// Aperçu d'impact recalculé seulement quand la couronne marque une pause : le nombre suit chaque cran,
    /// la courbe suit la main. Source: retour montre réelle 2026-09-05 — l'app ramait en rotation rapide
    /// (deux courbes et ~150 marques Swift Charts ré-animées à chaque cran).
    static let previewDelay: Duration = .milliseconds(90)

    enum Limits {
        /// Longueur maximale du nom d'une boisson personnalisée.
        /// Source: revue sécurité M5.4 — borne la saisie libre persistée dans l'App Group ; « Cappuccino décaféiné »
        /// tient en 21 caractères, 40 laisse de la marge sans déborder une ligne du carrousel.
        static let customDrinkNameMax = 40
    }
}

/// Durées et courbes d'animation (§2 et §5). `reduceMotion` remplace les springs par des ease courts (§6).
enum Motion {
    static let quick = 0.18
    static let colourDuration = 0.4

    static func snap(reduceMotion: Bool = false) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.25)
    }

    static func crown(reduceMotion: Bool = false) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.1) : .smooth(duration: quick)
    }

    static func colour(reduceMotion: Bool = false) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: colourDuration)
    }
}
