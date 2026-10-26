import Foundation
import Testing
@testable import PelmetCore

@Suite struct PanelOptionsTests {
    private func decode(_ json: String) throws -> PanelOptions {
        try JSONDecoder().decode(PanelOptions.self, from: Data(json.utf8))
    }

    @Test func defaultsAreCompactAutoAndFolded() throws {
        let options = PanelOptions()
        #expect(!options.showsNames)
        #expect(options.columnsWithNames == nil && options.columnsCompact == nil)
        #expect(!options.separatorsBreakRows)
        #expect(options.alwaysHidden == .folded)
        #expect(!options.alwaysHiddenOpen)
        #expect(options.alwaysHiddenFold == .tile)
        #expect(!options.showsClosedApps)
        #expect(PanelOptions.autoColumns == 5)
        #expect(try decode("{}") == options)
    }

    @Test func roundTrips() throws {
        var options = PanelOptions()
        options.showsNames = true
        options.columnsWithNames = 4
        options.columnsCompact = 7
        options.separatorsBreakRows = true
        options.alwaysHidden = .asLeft
        options.alwaysHiddenOpen = true
        options.alwaysHiddenFold = .handle
        options.showsClosedApps = true
        let back = try JSONDecoder().decode(PanelOptions.self, from: JSONEncoder().encode(options))
        #expect(back == options)
    }

    // One bad field resets that field and keeps the rest.
    @Test func aBadFieldKeepsTheOthers() throws {
        let options = try decode(#"""
        {"showsNames":"yes","columnsWithNames":6,"columnsCompact":"wide",
         "separatorsBreakRows":true,"alwaysHidden":"tucked","alwaysHiddenOpen":true,
         "alwaysHiddenFold":"drawer"}
        """#)
        #expect(options.showsNames == false)
        #expect(options.columnsWithNames == 6)
        #expect(options.columnsCompact == nil)
        #expect(options.separatorsBreakRows)
        #expect(options.alwaysHidden == .folded)
        #expect(options.alwaysHiddenOpen)
        #expect(options.alwaysHiddenFold == .tile)
    }

    @Test func aMissingFieldKeepsTheOthers() throws {
        let options = try decode(#"{"showsNames":true,"alwaysHidden":"hidden"}"#)
        #expect(options.showsNames)
        #expect(options.alwaysHidden == .hidden)
        #expect(options.columnsWithNames == nil && !options.separatorsBreakRows)
    }

    // A nil column count is Auto and stays nil; a stored one is pulled into
    // what the drag handle can reach.
    @Test func columnsStayInReach() throws {
        let wild = try decode(#"{"columnsWithNames":0,"columnsCompact":99}"#)
        #expect(wild.columnsWithNames == PanelOptions.columnRange.lowerBound)
        #expect(wild.columnsCompact == PanelOptions.columnRange.upperBound)
        let null = try decode(#"{"columnsWithNames":null}"#)
        #expect(null.columnsWithNames == nil)
    }

    // The edge drag writes whichever names mode is on; the other keeps its width.
    @Test func columnsFollowTheNamesMode() {
        var options = PanelOptions()
        options.columnsCompact = 7
        options.columnsWithNames = 4
        #expect(options.columns == 7)
        options.showsNames = true
        #expect(options.columns == 4)
        options.columns = 3
        #expect(options.columnsWithNames == 3 && options.columnsCompact == 7)
        options.columns = nil
        #expect(options.columnsWithNames == nil && options.columnsCompact == 7)
    }

    @Test func styleKeepsItsOwnColumnsAndFallsBackPerField() throws {
        var options = PanelOptions()
        #expect(options.style == .tiles)
        options.columnsCompact = 6
        options.style = .list
        #expect(options.columns == nil)
        options.columns = 2
        #expect(options.columnsList == 2 && options.columnsCompact == 6)
        options.style = .tight
        #expect(options.columns == nil)
        let bad = try JSONDecoder().decode(PanelOptions.self, from: Data(#"{"style":"mosaic","columnsList":3}"#.utf8))
        #expect(bad.style == .tiles && bad.columnsList == 3)
        let list = try JSONDecoder().decode(PanelOptions.self, from: Data(#"{"style":"list"}"#.utf8))
        #expect(list.style == .list)
    }

    // The tiles style without names and the tight style each keep their own
    // width: dragging one leaves the other where it was.
    @Test func tightAndPlainTilesDoNotShareAWidth() {
        var options = PanelOptions()
        options.style = .tight
        options.columns = 3
        options.style = .tiles
        #expect(options.columns == nil)
        options.columns = 8
        #expect(options.columnsCompact == 8 && options.columnsTight == 3)
        options.style = .tight
        #expect(options.columns == 3)
        options.columns = nil
        options.style = .tiles
        #expect(options.columns == 8)
    }

    // A blob saved before the tight style had its own width: both start from
    // the shared value, then part ways.
    @Test func olderBlobSeedsTightFromTheSharedWidth() throws {
        var options = try decode(#"{"style":"tight","columnsCompact":4}"#)
        #expect(options.columnsCompact == 4 && options.columnsTight == 4)
        options.columns = 6
        #expect(options.columnsCompact == 4 && options.columnsTight == 6)
    }

    // Auto saved for the tight style stays Auto: the null is written, so the
    // next load doesn't mistake it for an older blob and seed it again.
    @Test func tightAutoSurvivesASaveWhileCompactHasAWidth() throws {
        var options = PanelOptions()
        options.columnsCompact = 4
        options.style = .tight
        options.columns = nil
        let back = try JSONDecoder().decode(PanelOptions.self, from: JSONEncoder().encode(options))
        #expect(back.columnsTight == nil && back.columnsCompact == 4)
        #expect(back == options)
    }

    @Test func tightWidthIsPulledIntoReach() throws {
        let wild = try decode(#"{"columnsTight":99}"#)
        #expect(wild.columnsTight == PanelOptions.columnRange.upperBound)
        let bad = try decode(#"{"columnsTight":"wide","columnsCompact":5}"#)
        #expect(bad.columnsCompact == 5)
    }
}
