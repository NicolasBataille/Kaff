@testable import Kaff_Watch_App

final class SpyWidgetReloader: WidgetReloader, @unchecked Sendable {
    var reloadCount = 0
    func reloadAll() { reloadCount += 1 }
}
