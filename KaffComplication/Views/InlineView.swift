import KaffCore
import SwiftUI
import WidgetKit

/// « ☕ 142 mg · OK » sur une ligne (symbole SF interpolé pour rester monochrome sur les cadrans teintés).
struct InlineView: View {
    let data: WidgetEntryData

    var body: some View {
        if data.hasData {
            Text("\(Image(systemName: "cup.and.saucer.fill")) \(Formatters.mg(data.milligrams)) · \(data.status.label)")
                .accessibilityLabel(data.accessibilityText)
        } else {
            Text("\(Image(systemName: "cup.and.saucer.fill")) \(WidgetEntryData.openAppLabel)")
        }
    }
}
