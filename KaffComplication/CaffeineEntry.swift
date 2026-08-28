import KaffCore
import WidgetKit

struct CaffeineEntry: TimelineEntry {
    let data: WidgetEntryData
    var date: Date { data.date }
}
