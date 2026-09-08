import KaffCore

extension DisplayUnit {
    /// Étiquette courte, identique dans l'app et la complication (« mg » / « mg/L »).
    var label: String {
        switch self {
        case .milligrams: "mg"
        case .milligramsPerLitre: "mg/L"
        }
    }

    /// Libellé VoiceOver (« milligrammes » / « milligrammes par litre »).
    var accessibilityLabel: String {
        switch self {
        case .milligrams: "milligrammes"
        case .milligramsPerLitre: "milligrammes par litre"
        }
    }
}
