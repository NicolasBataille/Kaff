import Foundation

public struct TimelinePoint: Hashable, Sendable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let milligrams: Double
    public let status: LevelStatus

    public init(date: Date, milligrams: Double, status: LevelStatus) {
        self.date = date
        self.milligrams = milligrams
        self.status = status
    }
}
