import Testing
@testable import KaffCore

@Test func packageLoads() {
    #expect(KaffCore.version == "0.1.0")
}
