import Foundation
import Testing
@testable import Kaff_Watch_App

/// `DebouncedSaver` : replanification par cran, `flush()` à la disparition.
@MainActor
struct DebouncedSaverTests {
    /// Compteur partagé entre le test et les fermetures planifiées (tout sur le MainActor).
    @MainActor final class Counter {
        var runs = 0
        var last = ""
        func hit(_ tag: String = "") { runs += 1; last = tag }
    }

    let counter = Counter()

    /// Attend (au plus 1 s) que `condition` soit vraie, en laissant tourner les tâches planifiées.
    private func settle(until condition: @MainActor () -> Bool = { false }) async {
        let deadline = ContinuousClock.now + .seconds(1)
        while !condition(), ContinuousClock.now < deadline {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func scheduleRunsClosureOnceAfterDelay() async {
        let saver = DebouncedSaver(delay: .zero)
        saver.schedule { [counter] in counter.hit() }
        await settle { counter.runs == 1 }
        #expect(counter.runs == 1)
        await settle()
        #expect(counter.runs == 1)
    }

    @Test func rapidSchedulesRunOnlyTheLast() async {
        let saver = DebouncedSaver(delay: .zero)
        saver.schedule { [counter] in counter.hit("first") }
        saver.schedule { [counter] in counter.hit("second") }
        await settle { counter.runs == 1 }
        await settle()
        #expect(counter.runs == 1)
        #expect(counter.last == "second")
    }

    @Test func flushRunsPendingImmediatelyAndOnce() async {
        let saver = DebouncedSaver(delay: .seconds(10))
        saver.schedule { [counter] in counter.hit() }
        #expect(counter.runs == 0)
        saver.flush()
        await settle { counter.runs == 1 }
        #expect(counter.runs == 1)
        await settle()
        #expect(counter.runs == 1)
    }

    @Test func flushWithNothingPendingDoesNothing() async {
        let saver = DebouncedSaver(delay: .zero)
        saver.flush()
        await settle()
        #expect(counter.runs == 0)
    }

    @Test func scheduleAfterFlushWorksAgain() async {
        let saver = DebouncedSaver(delay: .zero)
        saver.schedule { [counter] in counter.hit("a") }
        saver.flush()
        await settle { counter.runs == 1 }
        saver.schedule { [counter] in counter.hit("b") }
        await settle { counter.runs == 2 }
        #expect(counter.runs == 2)
        #expect(counter.last == "b")
    }
}
