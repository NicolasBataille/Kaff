import KaffCore
import SwiftUI

/// Heure de coucher réglée à la couronne : crans de 5 min, boucle sur 24 h, sauvegarde différée (`DebouncedSaver`).
struct BedtimePickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var dialFocused: Bool

    /// Position en crans de `stepMinutes` depuis minuit.
    @State private var steps = 0.0
    @State private var isLoaded = false
    @State private var saver = DebouncedSaver()

    private static let stepMinutes = 5.0
    private static let stepsPerDay = 24 * 60 / stepMinutes

    private var clock: ClockTime {
        let minutes = Int(steps.rounded()) * Int(Self.stepMinutes)
        return ClockTime(hour: (minutes / 60) % 24, minute: minutes % 60)
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "moon.zzz.fill")
                .font(.title2)
                .foregroundStyle(Theme.sleep)
                .accessibilityHidden(true)
            Text(Formatters.time(clock))
                .font(Theme.Typography.hero)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(Motion.crown(reduceMotion: reduceMotion), value: steps)
            Text("Limite à cette heure : \(Formatters.mg(model.profile.bedtimeLimitMg)).")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .focused($dialFocused)
        .digitalCrownRotation($steps, from: 0, through: Self.stepsPerDay - 1, by: 1,
                              sensitivity: .medium, isContinuous: true, isHapticFeedbackEnabled: true)
        .navigationTitle("Coucher")
        .onAppear {
            steps = Double(model.profile.bedtime.minutesOfDay) / Self.stepMinutes
            isLoaded = true
            dialFocused = true
        }
        .onDisappear {
            dialFocused = false
            saver.flush()
        }
        .onChange(of: clock) { _, new in
            guard isLoaded else { return }
            saver.schedule { await save(new) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heure de coucher")
        .accessibilityValue(Formatters.time(clock))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: steps = (steps + 1).truncatingRemainder(dividingBy: Self.stepsPerDay)
            case .decrement: steps = (steps - 1 + Self.stepsPerDay).truncatingRemainder(dividingBy: Self.stepsPerDay)
            @unknown default: break
            }
        }
    }

    private func save(_ bedtime: ClockTime) async {
        guard bedtime != model.profile.bedtime else { return }
        var profile = model.profile
        profile.bedtime = bedtime
        await model.update(profile: profile)
    }
}
