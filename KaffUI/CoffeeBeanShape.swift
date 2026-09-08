import SwiftUI

/// Grain de café vectoriel (spec §8 « Grain de café (v0.3) », aucun asset) : ellipse inclinée avec le sillon
/// central en S découpé. Le sillon est un trou (règle pair-impair), jamais peint : le fond varie (glow de Home,
/// noir Always-On, teinte de cadran en `.accented`). Remplir avec `FillStyle(eoFill: true)`.
///
/// Le grand axe vaut le côté du carré inscrit : l'ellipse tient dans le cercle quelle que soit l'inclinaison,
/// donc dans l'ouverture d'un anneau. Filigrane statique (`Theme.Ring.beanOpacity`), pas d'animation.
struct CoffeeBeanShape: Shape {
    /// Inclinaison du grand axe (sens horaire) ; ≈ 30° d'après le brief M7.4.
    var tilt: Angle = .degrees(30)

    /// Petit axe / grand axe d'un grain arabica (≈ 0,65 sur une photo de profil).
    private static let aspect = 0.65
    /// Le sillon s'arrête un peu avant les pointes (proportion du demi-grand axe).
    private static let furrowReach = 0.82
    /// Amplitude latérale du S (proportion du demi-grand axe).
    private static let furrowSway = 0.22
    /// Épaisseur du sillon (proportion du demi-petit axe).
    private static let furrowWidth = 0.16

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let a = min(rect.width, rect.height) / 2
        let b = a * Self.aspect

        var bean = Path(ellipseIn: CGRect(x: -b, y: -a, width: 2 * b, height: 2 * a))

        var furrow = Path()
        let reach = a * Self.furrowReach
        let sway = a * Self.furrowSway
        furrow.move(to: CGPoint(x: 0, y: -reach))
        furrow.addCurve(to: CGPoint(x: 0, y: reach),
                        control1: CGPoint(x: -sway, y: -reach / 3),
                        control2: CGPoint(x: sway, y: reach / 3))
        bean.addPath(furrow.strokedPath(StrokeStyle(lineWidth: b * Self.furrowWidth, lineCap: .round)))

        let transform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: tilt.radians)
        return bean.applying(transform)
    }
}

#Preview {
    VStack(spacing: 16) {
        CoffeeBeanShape()
            .fill(Theme.accent, style: FillStyle(eoFill: true))
            .frame(width: 120, height: 120)
        CoffeeBeanShape()
            .fill(Theme.Status.ok.opacity(Theme.Ring.beanOpacity), style: FillStyle(eoFill: true))
            .frame(width: 44, height: 44)
            .background(.black)
    }
}
