import CoreGraphics
import Testing
@testable import PelmetCore

@Suite struct MenuBarShownTests {
    let display = CGRect(x: 0, y: 0, width: 1512, height: 982)

    @Test func noWindowsCannotJudge() {
        #expect(MenuBarShown.isShown(on: display, windows: []) == nil)
    }

    @Test func barDownIsShown() {
        let bar = MenuBarShown.Window(bounds: CGRect(x: 0, y: 0, width: 1512, height: 33), onScreen: true)
        #expect(MenuBarShown.isShown(on: display, windows: [bar]) == true)
    }

    @Test func hiddenAboveTheEdge() {
        let bar = MenuBarShown.Window(bounds: CGRect(x: 0, y: -33, width: 1512, height: 33), onScreen: true)
        #expect(MenuBarShown.isShown(on: display, windows: [bar]) == false)
    }

    @Test func midSlideIsNotShown() {
        let bar = MenuBarShown.Window(bounds: CGRect(x: 0, y: -12, width: 1512, height: 33), onScreen: true)
        #expect(MenuBarShown.isShown(on: display, windows: [bar]) == false)
    }

    @Test func offScreenWindowIsNotShown() {
        let bar = MenuBarShown.Window(bounds: CGRect(x: 0, y: 0, width: 1512, height: 33), onScreen: false)
        #expect(MenuBarShown.isShown(on: display, windows: [bar]) == false)
    }

    @Test func otherDisplaysBarDoesNotCount() {
        let other = MenuBarShown.Window(bounds: CGRect(x: 1512, y: 0, width: 2560, height: 33), onScreen: true)
        #expect(MenuBarShown.isShown(on: display, windows: [other]) == false)
        let side = CGRect(x: 1512, y: -200, width: 2560, height: 1440)
        // Secondary display whose top is at y -200: its bar sits at -200.
        let otherBar = MenuBarShown.Window(bounds: CGRect(x: 1512, y: -200, width: 2560, height: 33), onScreen: true)
        #expect(MenuBarShown.isShown(on: side, windows: [otherBar]) == true)
    }

    @Test func faintWindowIsNotShown() {
        let bar = MenuBarShown.Window(bounds: CGRect(x: 0, y: 0, width: 1512, height: 33), onScreen: true, alpha: 0)
        #expect(MenuBarShown.isShown(on: display, windows: [bar]) == false)
    }
}
