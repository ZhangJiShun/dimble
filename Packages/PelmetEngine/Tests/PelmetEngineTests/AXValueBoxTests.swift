import ApplicationServices
import CoreGraphics
import Testing
@testable import PelmetEngine

@Suite struct AXValueBoxTests {
    @Test func roundTripsAXValueCreatedPointsSizesAndRects() {
        var point = CGPoint(x: 12.5, y: -3)
        #expect(AXValueBox.cgPoint(from: AXValueCreate(.cgPoint, &point)) == point)

        var size = CGSize(width: 40, height: 18)
        #expect(AXValueBox.cgSize(from: AXValueCreate(.cgSize, &size)) == size)

        var rect = CGRect(x: 1, y: 2, width: 3, height: 4)
        #expect(AXValueBox.cgRect(from: AXValueCreate(.cgRect, &rect)) == rect)
    }

    @Test func rejectsNonAXValues() {
        let cfString: CFTypeRef = "not an AXValue" as CFString
        #expect(AXValueBox.cgPoint(from: cfString) == nil)
        #expect(AXValueBox.cgSize(from: cfString) == nil)
        #expect(AXValueBox.cgRect(from: cfString) == nil)

        let swiftString: CFTypeRef = "plain Swift String" as String as CFTypeRef
        #expect(AXValueBox.cgPoint(from: swiftString) == nil)
        #expect(AXValueBox.cgSize(from: swiftString) == nil)
        #expect(AXValueBox.cgRect(from: swiftString) == nil)
    }

    @Test func nilIsNil() {
        #expect(AXValueBox.cgPoint(from: nil) == nil)
        #expect(AXValueBox.cgSize(from: nil) == nil)
        #expect(AXValueBox.cgRect(from: nil) == nil)
    }
}
