import KaffCore
import SwiftUI

/// Pastille de statut en verre, tintée ; tap → explication (brief §3.1).
struct StatusPillView: View {
    let status: LevelStatus
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: status.symbol)
                    .contentTransition(.symbolEffect(.replace))
                Text(status.label)
                    .contentTransition(.interpolate)
            }
            .font(.caption.weight(.semibold))
            .fixedSize()
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(.regular.tint(status.color.opacity(0.22)).interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .animation(Motion.colour(reduceMotion: reduceMotion), value: status)
        .accessibilityLabel("Statut : \(status.label)")
        .accessibilityHint("Affiche le détail des trois vérifications")
    }
}
