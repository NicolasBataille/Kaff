import Foundation

/// Repères de toxicité de la concentration plasmatique (mg/L). Informatifs, jamais un seuil de statut : le statut
/// « trop haut » se déclenche dès ≈ 4 mg/L et le modèle est documenté non linéaire au-delà de 500 mg (spec §5.3).
public enum ConcentrationReference {
    /// Source: Willson 2018, « The clinical toxicology of caffeine: A review and case study », Toxicol Rep 5:1140-1152
    /// (DOI 10.1016/j.toxrep.2018.11.002) ; revue Frontiers in Toxicology 2026 (DOI 10.3389/ftox.2026.1933375) —
    /// symptômes d'intoxication (agitation, vomissements, tachyarythmies) à partir de 15 mg/L.
    public static let symptomsMgPerLitre = 15.0
    /// Source: idem — concentrations > 50 mg/L considérées toxiques.
    public static let toxicMgPerLitre = 50.0
    /// Source: idem — > 80 mg/L associées à des issues fatales (fibrillation ventriculaire, séries suédoises).
    public static let lethalMgPerLitre = 80.0
}
