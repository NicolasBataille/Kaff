import KaffCore
import SwiftUI
import WidgetKit

/// « ☕ 142 mg · OK » sur une ligne (symbole SF interpolé pour rester monochrome sur les cadrans teintés) ;
/// « ☕ 142 mg · Ouvrir Kaff » quand le snapshot est obsolète (spec §8).
struct InlineView: View {
    let data: WidgetEntryData

    var body: some View {
        if data.hasData {
            Text("\(Image(systemName: "cup.and.saucer.fill")) \(data.valueWithUnit) · \(data.inlineSuffix)")
                .accessibilityLabel(data.accessibilityText)
        } else {
            Text("\(Image(systemName: "cup.and.saucer.fill")) \(WidgetEntryData.openAppLabel)")
        }
    }
}
