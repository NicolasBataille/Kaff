import SwiftUI

/// Anneau de niveau (Home, cadran mg, complication M4) : arc 300° ouvert en bas, dégradé angulaire
/// de la teinte de statut, extrémité arrondie avec glow, couche fine rouge pour le dépassement.
/// Le remplissage et la couleur sont animés ; les valeurs sont attendues dans 0…1.
/// `showsBean` (v0.3) : grain de café en filigrane dans l'ouverture, teinte de l'anneau à `Theme.Ring.beanOpacity` —
/// réservé aux anneaux où un nombre se lit au centre (héros, cadran mg, circulaire), pas aux mini-anneaux.
struct KaffRingView: View {
    var progress: Double
    var overflowProgress: Double = 0
    var tint: Color
    var lineWidth: Double = Theme.Ring.lineWidth
    var isAnimated = true
    var showsBean = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sweep: Double { Theme.Ring.sweepDegrees }
    private var clampedProgress: Double { min(max(progress, 0), 1) }
    private var clampedOverflow: Double { min(max(overflowProgress, 0), 1) }
    /// Ouverture centrée en bas : le tracé part en bas à gauche et tourne dans le sens horaire.
    private var startRotation: Angle { .degrees(90 + (360 - sweep) / 2) }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                // Hors du ZStack tourné : le grain garde sa propre inclinaison (30°), pas celle du tracé (120°).
                if showsBean { bean }
                ZStack {
                    track
                    fill
                    if clampedOverflow > 0 { overflow(side: side) }
                    tip(radius: side / 2 - lineWidth / 2)
                }
                .rotationEffect(startRotation)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(isAnimated ? Motion.snap(reduceMotion: reduceMotion) : nil, value: clampedProgress)
        .animation(isAnimated ? Motion.snap(reduceMotion: reduceMotion) : nil, value: clampedOverflow)
        .animation(isAnimated ? Motion.colour(reduceMotion: reduceMotion) : nil, value: tint)
        .accessibilityHidden(true)
    }

    /// Filigrane statique : la teinte suit le statut (et la teinte du cadran en `.accented`), le sillon est un trou.
    private var bean: some View {
        CoffeeBeanShape()
            .fill(tint.opacity(Theme.Ring.beanOpacity), style: FillStyle(eoFill: true))
            .padding(lineWidth * Theme.Ring.beanInset)
            .transition(.opacity)
    }

    private var track: some View {
        Circle()
            .trim(from: 0, to: sweep / 360)
            .stroke(tint.opacity(Theme.Ring.trackOpacity), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .padding(lineWidth / 2)
    }

    private var fill: some View {
        Circle()
            .trim(from: 0, to: sweep / 360 * clampedProgress)
            .stroke(
                AngularGradient(colors: [tint.opacity(0.45), tint], center: .center,
                                startAngle: .degrees(0), endAngle: .degrees(sweep)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .padding(lineWidth / 2)
    }

    private func overflow(side: Double) -> some View {
        Circle()
            .trim(from: 0, to: sweep / 360 * clampedOverflow)
            .stroke(Theme.Status.high, style: StrokeStyle(lineWidth: Theme.Ring.overflowLineWidth, lineCap: .round))
            .padding(lineWidth + Theme.Ring.overflowLineWidth)
    }

    /// Point lumineux à l'extrémité de l'arc (glow discret, masqué à zéro).
    private func tip(radius: Double) -> some View {
        Circle()
            .fill(tint)
            .frame(width: lineWidth, height: lineWidth)
            .shadow(color: tint.opacity(reduceMotion ? 0 : 0.8), radius: lineWidth / 2)
            .offset(x: radius)
            .rotationEffect(.degrees(sweep * clampedProgress))
            .opacity(clampedProgress > 0.005 ? 1 : 0)
    }
}

#Preview {
    VStack {
        KaffRingView(progress: 0.7, tint: Theme.Status.ok, showsBean: true).frame(width: 120)
        KaffRingView(progress: 1, overflowProgress: 0.3, tint: Theme.Status.high).frame(width: 80)
        KaffRingView(progress: 0.4, tint: Theme.Status.elevated, lineWidth: Theme.Ring.complicationLineWidth,
                     isAnimated: false, showsBean: true).frame(width: 50)
    }
}
