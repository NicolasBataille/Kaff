import KaffCore
import SwiftUI
import WatchKit

/// Home — « Maintenant » : anneau + nombre héros, pastille, sommeil, courbe scrubbable à la couronne, actions.
/// Le mode scrub (brief §3.1) est explicite : tap sur l'anneau ou la courbe ; la disposition se compacte
/// (mini-anneau + nombre + pastille, courbe agrandie) pour que la valeur et le curseur restent visibles ensemble.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.zoomNamespace) private var zoom
    @Namespace private var morph

    @State private var hasAppeared = false
    @State private var points: [TimelinePoint] = []
    @State private var isScrubbing = false
    /// Position du scrubber en crans de `Theme.Scrub.stepMinutes` (1 unité = 1 cran haptique de la couronne).
    @State private var scrubSteps = 0.0
    @State private var scrubIdleTask: Task<Void, Never>?
    @State private var showStatusDetail = false
    @FocusState private var scrubFocused: Bool

    private static let emptyWindowHours = 24.0
    /// Délai de grâce après l'entrée en mode scrub (avant la première rotation).
    private static let scrubEntryGrace: Duration = .milliseconds(2500)
    private static let topAnchor = "top"

    private var ringSize: Double { min(WKInterfaceDevice.current().screenBounds.width * 0.62, 132) }
    private var miniRingSize: Double { ringSize * 0.36 }
    /// Hauteur de courbe en mode scrub : 96 pt, réduite sur les petits boîtiers pour rester entièrement visible.
    private var scrubChartHeight: Double { min(Theme.Chart.scrubbingHeight, WKInterfaceDevice.current().screenBounds.height * 0.4) }
    private var snap: Animation { Motion.snap(reduceMotion: reduceMotion) }

    var body: some View {
        // `.everyMinute` est un planning stable : `.periodic(from: .now)` en recréerait un à chaque rendu (boucle).
        TimelineView(.everyMinute) { context in
            content(now: context.date)
        }
        .navigationTitle("Kaff")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.settings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Réglages")
            }
        }
        .onAppear {
            guard !hasAppeared else { return }
            withAnimation(snap) { hasAppeared = true }
        }
        .onDisappear { exitScrub(animated: false) }
    }

    private func content(now: Date) -> some View {
        let live = model.assessment(at: now)
        let shown = isScrubbing ? model.assessment(at: scrubDate(now)) : live
        let isEmpty = !model.doses.contains { $0.date >= now.addingTimeInterval(-Self.emptyWindowHours * 3600) }
        let tint = isEmpty ? Theme.idle : shown.status.color

        return ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 6) {
                    Color.clear.frame(height: 0).id(Self.topAnchor)
                    if isScrubbing {
                        scrubHeader(now: now)
                        compactHero(shown, tint: tint)
                    } else {
                        hero(shown, tint: tint, isEmpty: isEmpty)
                        if isEmpty {
                            Text("Aucune caféine dans le sang.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        } else {
                            StatusPillView(status: shown.status) { showStatusDetail = true }
                            sleepLine(shown)
                        }
                    }
                    if !isLuminanceReduced {
                        if !isEmpty { chart(now: now, shown: shown, tint: tint) }
                        if !isScrubbing {
                            weightBadge
                            actions
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 4)
                .animation(snap, value: isScrubbing)
            }
            .onChange(of: isScrubbing) { _, scrubbing in
                if scrubbing { withAnimation(snap) { proxy.scrollTo(Self.topAnchor, anchor: .top) } }
            }
        }
        .onChange(of: ChartKey(now: now, doses: model.doses, profile: model.profile), initial: true) { _, key in
            points = model.chartPoints(from: key.now.addingTimeInterval(-Theme.Chart.pastHours * 3600),
                                       hours: Theme.Chart.pastHours + Theme.Chart.futureHours,
                                       stepMinutes: Theme.Chart.stepMinutes)
        }
        .sheet(isPresented: $showStatusDetail) {
            NavigationStack {
                StatusDetailSheet(assessment: shown, profile: model.profile)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fermer", systemImage: "xmark") { showStatusDetail = false }
                        }
                    }
            }
        }
        .sensoryFeedback(.selection, trigger: isScrubbing)
        .sensoryFeedback(.warning, trigger: live.status) { _, new in new == .high }
    }

    // MARK: Héros

    private func hero(_ assessment: LevelAssessment, tint: Color, isEmpty: Bool) -> some View {
        let mg = hasAppeared ? assessment.currentMg : 0
        return ZStack {
            if !isLuminanceReduced {
                Circle()
                    .fill(RadialGradient(colors: [tint.opacity(Theme.glowOpacity), .clear],
                                         center: .center, startRadius: 0, endRadius: ringSize * 0.75))
                    .frame(width: ringSize * 1.5, height: ringSize * 1.5)
                    .animation(Motion.colour(reduceMotion: reduceMotion), value: tint)
            }
            ring(mg: mg, tint: tint, lineWidth: Theme.Ring.lineWidth)
                .frame(width: ringSize, height: ringSize)
            VStack(spacing: -2) {
                heroNumber(mg, font: Theme.Typography.hero)
                Text("mg")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: ringSize - Theme.Ring.lineWidth * 3)
        }
        .frame(height: ringSize)
        .contentShape(Circle())
        .onTapGesture { if !isEmpty { toggleScrub() } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isEmpty ? "Aucune caféine" : "\(Formatters.mgValue(assessment.currentMg)) milligrammes, \(assessment.status.accessibilityLabel)")
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityHint(isEmpty ? "" : "Touchez pour explorer la courbe avec la couronne")
    }

    /// Disposition compacte du mode scrub, sur une ligne : mini-anneau, nombre à l'instant visé, statut projeté.
    private func compactHero(_ assessment: LevelAssessment, tint: Color) -> some View {
        HStack(spacing: 8) {
            ring(mg: assessment.currentMg, tint: tint, lineWidth: Theme.Ring.lineWidth * 0.5)
                .frame(width: miniRingSize, height: miniRingSize)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                heroNumber(assessment.currentMg, font: Theme.Typography.heroCompact)
                Text("mg")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            StatusPillView(status: assessment.status) { showStatusDetail = true }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { toggleScrub() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Formatters.relative(minutes: scrubOffsetMinutes)) : \(Formatters.mgValue(assessment.currentMg)) milligrammes, \(assessment.status.accessibilityLabel)")
    }

    private func ring(mg: Double, tint: Color, lineWidth: Double) -> some View {
        let limit = max(model.profile.singleDoseLimitMg, 1)
        return KaffRingView(progress: min(mg / limit, 1), overflowProgress: max(mg / limit - 1, 0),
                            tint: tint, lineWidth: lineWidth, isAnimated: !isLuminanceReduced)
            .matchedGeometryEffect(id: "ring", in: morph)
    }

    private func heroNumber(_ mg: Double, font: Font) -> some View {
        Text(Formatters.mgValue(mg))
            .font(font)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(Theme.Typography.heroMinimumScale)
            .contentTransition(.numericText(value: mg))
            .animation(isScrubbing ? Motion.crown(reduceMotion: reduceMotion) : snap, value: mg)
            .matchedGeometryEffect(id: "number", in: morph)
    }

    // MARK: Sections

    private func scrubHeader(now: Date) -> some View {
        Text("\(Formatters.relative(minutes: scrubOffsetMinutes)) · \(Formatters.time(scrubDate(now)))")
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(Theme.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .contentTransition(.numericText())
            .animation(Motion.crown(reduceMotion: reduceMotion), value: scrubSteps)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func sleepLine(_ assessment: LevelAssessment) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "moon.zzz.fill")
                .foregroundStyle(Theme.sleep)
            Text(assessment.isSleepReady ? "OK pour dormir maintenant" : "OK pour dormir à \(Formatters.time(assessment.sleepReadyAt))")
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(.footnote)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .animation(Motion.colour(reduceMotion: reduceMotion), value: assessment.sleepReadyAt)
        .accessibilityElement(children: .combine)
    }

    private func chart(now: Date, shown: LevelAssessment, tint: Color) -> some View {
        CaffeineChartView(
            points: points, now: now, limitMg: model.profile.singleDoseLimitMg,
            cursor: isScrubbing ? (scrubDate(now), shown.currentMg, tint) : nil)
            .frame(height: isScrubbing ? scrubChartHeight : Theme.Chart.restingHeight)
            .padding(.top, 4)
            .contentShape(Rectangle())
            .onTapGesture { toggleScrub() }
            .focusable(isScrubbing)
            .focused($scrubFocused)
            .digitalCrownRotation($scrubSteps, from: Theme.Scrub.minSteps, through: Theme.Scrub.maxSteps,
                                  by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
            .onChange(of: scrubSteps) { _, _ in if isScrubbing { scheduleScrubExit(after: Theme.Scrub.idleExit) } }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(isScrubbing ? "Tournez la couronne pour explorer, touchez pour quitter" : "Touchez pour explorer la courbe avec la couronne")
            .accessibilityValue(isScrubbing ? Formatters.relative(minutes: scrubOffsetMinutes) : "")
    }

    @ViewBuilder private var weightBadge: some View {
        if model.profile.isWeightEstimated {
            NavigationLink(value: Route.settings) {
                Label("Poids estimé (\(Formatters.kg(model.profile.weightKg)))", systemImage: "scalemass")
                    .font(.caption2)
                    .foregroundStyle(Theme.Status.elevated)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Ouvre les réglages")
        }
    }

    private var actions: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                NavigationLink(value: Route.logDrink) {
                    Label("Boisson", systemImage: "cup.and.saucer.fill")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)
                .zoomSource(id: Route.logDrink, in: zoom)
                .accessibilityLabel("Ajouter une boisson")

                NavigationLink(value: Route.logManual) {
                    Label("mg", systemImage: "number")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .zoomSource(id: Route.logManual, in: zoom)
                .accessibilityLabel("Ajouter une dose en milligrammes")
            }
        }
        .padding(.top, 4)
    }

    // MARK: Scrub

    private var scrubOffsetMinutes: Double { scrubSteps * Theme.Scrub.stepMinutes }
    private func scrubDate(_ now: Date) -> Date { now.addingTimeInterval(scrubOffsetMinutes * 60) }

    private func toggleScrub() {
        if isScrubbing { exitScrub(animated: true) } else { enterScrub() }
    }

    private func enterScrub() {
        withAnimation(snap) { isScrubbing = true }
        // Le focus ne peut être pris qu'une fois la vue devenue focalisable (transaction suivante).
        Task { @MainActor in
            await Task.yield()
            scrubFocused = true
        }
        scheduleScrubExit(after: Self.scrubEntryGrace)
    }

    private func exitScrub(animated: Bool) {
        scrubIdleTask?.cancel()
        scrubIdleTask = nil
        guard isScrubbing else { return }
        scrubFocused = false
        if animated {
            withAnimation(snap) {
                isScrubbing = false
                scrubSteps = 0
            }
        } else {
            isScrubbing = false
            scrubSteps = 0
        }
    }

    private func scheduleScrubExit(after delay: Duration) {
        scrubIdleTask?.cancel()
        scrubIdleTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            exitScrub(animated: true)
        }
    }

    /// Clé de recalcul de la courbe : une fois par minute ou quand les doses / le profil changent.
    private struct ChartKey: Equatable {
        let now: Date
        let doses: [CaffeineDose]
        let profile: UserProfile
    }
}
