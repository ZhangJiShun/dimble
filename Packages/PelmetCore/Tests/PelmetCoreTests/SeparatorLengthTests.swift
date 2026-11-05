import Foundation
import Testing
@testable import PelmetCore

@Suite struct SeparatorLengthTests {
    @Test func spacerCarriesItsWidth() {
        let spec = SeparatorSpec(style: .space, width: 32)
        #expect(spec.hostedLength == 32)
        #expect(SeparatorLength.appliedLength(hostedLength: spec.hostedLength) == 32)
    }

    @Test func glyphsIgnoreWidthAndUseVariableLength() {
        #expect(SeparatorLength.variable == -1)
        for style: SeparatorStyle in [.pipe, .dot] {
            let spec = SeparatorSpec(style: style, width: 32)
            #expect(spec.hostedLength == nil)
            #expect(SeparatorLength.appliedLength(hostedLength: spec.hostedLength) == -1)
        }
    }

    @Test func aDefaultWidthSpacerIsFourteenNotAHardcodedShownLength() {
        // Old JSON without `width` still decodes as defaultWidth (14). shownLength
        // used to hardcode 14 for every spacer; a user slider at 32 must apply 32.
        let spec = SeparatorSpec(style: .space)
        #expect(spec.width == SeparatorSpec.defaultWidth)
        #expect(spec.hostedLength == 14)
        let widened = SeparatorSpec(style: .space, width: 32)
        #expect(SeparatorLength.appliedLength(hostedLength: widened.hostedLength) == 32)
        #expect(SeparatorLength.appliedLength(hostedLength: widened.hostedLength) != 14)
    }

    @Test func leftoverSpacerWidthMustResetWhenSwitchingToAGlyph() {
        #expect(SeparatorLength.needsLengthWrite(currentLength: 32, hostedLength: nil) == true)
    }

    @Test func aSpacerAlreadyAtItsWidthDoesNotNeedAWrite() {
        #expect(SeparatorLength.needsLengthWrite(currentLength: 32, hostedLength: 32) == false)
    }

    @Test func aGlyphMustWriteWhenBecomingASpacer() {
        #expect(SeparatorLength.needsLengthWrite(currentLength: -1, hostedLength: 20) == true)
    }

    @Test func aGlyphAlreadyAtVariableLengthDoesNotNeedAWrite() {
        #expect(SeparatorLength.needsLengthWrite(currentLength: -1, hostedLength: nil) == false)
    }
}
