import Foundation

/// Session de sommeil telle que lue dans Santé (`sleepAnalysis`), déjà réduite à ce que
/// `BedtimeInference` utilise : les phases `asleep*` de HealthKit sont fusionnées en `.asleep`,
/// les périodes `awake` ne sont pas représentées.
public struct SleepSession: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case inBed
        case asleep
    }

    public let start: Date
    public let end: Date
    public let kind: Kind

    public init(start: Date, end: Date, kind: Kind) {
        self.start = start
        self.end = end
        self.kind = kind
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }
}
