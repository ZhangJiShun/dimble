import Foundation
import Testing
@testable import PelmetCore

struct PanelItemImageSourceTests {
    private func key(_ spec: ExtraItemSpec, owner: String = PelmetBundle.fallbackID) -> ItemID {
        .status(bundle: owner, title: spec.itemTitle)
    }

    @Test func pinnedLauncherUsesItsConfigurationInsteadOfACapturedOverflowGlyph() {
        let launcher = ExtraItemSpec(kind: .appLauncher, bundleID: "com.tencent.tenvideo", appName: "腾讯视频")
        let source = PanelItemImageSource.resolve(for: key(launcher), extras: [launcher])
        // An existing picture may contain Apple's « button. The launcher
        // must never use that crop as its displayed image.
        #expect(source == .appIcon("com.tencent.tenvideo"))
    }

    @Test func nativeAppIconIgnoresSymbolOverridesButFollowsTheExactLauncher() {
        let plain = ExtraItemSpec(kind: .appLauncher, bundleID: "com.example.app")
        let custom = ExtraItemSpec(kind: .appLauncher, symbol: "star.fill", bundleID: "com.example.app")
        #expect(PanelItemImageSource.resolve(for: key(custom), extras: [plain, custom]) == .appIcon("com.example.app"))
        var edited = custom
        edited.symbol = "heart.fill"
        #expect(PanelItemImageSource.resolve(for: key(custom), extras: [plain, edited]) == .appIcon("com.example.app"))
        edited.symbol = nil
        edited.bundleID = "com.example.changed"
        #expect(PanelItemImageSource.resolve(for: key(custom), extras: [edited]) == .appIcon("com.example.changed"))
    }

    @Test func helperHostedLauncherKeepsItsConfiguredImage() {
        let launcher = ExtraItemSpec(kind: .appLauncher, bundleID: "com.example.app", showRule: .whenActive)
        for owner in PelmetBundle.ownIDs {
            #expect(PanelItemImageSource.resolve(for: key(launcher, owner: owner), extras: [launcher]) == .appIcon("com.example.app"))
        }
    }

    @Test func removedLauncherCannotResurrectAnOldScreenshot() {
        let launcher = ExtraItemSpec(kind: .appLauncher, bundleID: "com.example.app")
        let source = PanelItemImageSource.resolve(for: key(launcher), extras: [])
        #expect(source == .unavailable)
    }

    @Test func ordinaryAppsUseTheirLocalIconsInsteadOfAnyMenuBarPicture() {
        let launcher = ExtraItemSpec(kind: .appLauncher, bundleID: "com.example.app")
        let items: [ItemID] = [
            .bundleKey("com.example.app"),
            key(launcher, owner: "com.example.other"),
        ]
        for item in items {
            let source = PanelItemImageSource.resolve(for: item, extras: [launcher])
            #expect(source == .appIcon(item.bundleID!))
        }
    }

    @Test func nativeSystemFunctionsKeepTheirSystemArtwork() {
        for item in [ItemID.module("Clock"), .status(bundle: PelmetBundle.agentID, title: "com.apple.menuextra.wifi"),
                     key(ExtraItemSpec(kind: .mediaControls))] {
            #expect(PanelItemImageSource.resolve(for: item, extras: []) == .systemItem)
        }
    }

    @Test func embeddedBrowserUsesTheMainApplicationIcon() {
        let main = URL(fileURLWithPath: "/Applications/DoubaoWork.app")
        let browser = main.appendingPathComponent("Contents/Helpers/DoubaoWork Browser.app")
        let renderer = browser.appendingPathComponent("Contents/Frameworks/Browser.framework/Helpers/Renderer.app")
        #expect(PanelItemImageSource.applicationIconURL(for: browser) == main)
        #expect(PanelItemImageSource.applicationIconURL(for: renderer) == main)
    }

    @Test func standaloneAppsAndOrdinaryAppNamedFoldersAreHandledWithoutParentWalks() {
        let standalone = URL(fileURLWithPath: "/Applications/腾讯视频.app")
        #expect(PanelItemImageSource.applicationIconURL(for: standalone) == standalone)
        let folder = URL(fileURLWithPath: "/Users/Example.app/projects/Actual.app")
        #expect(PanelItemImageSource.applicationIconURL(for: folder) == folder)
        let web = URL(string: "https://example.com/App.app/Contents/Helper.app")!
        #expect(PanelItemImageSource.applicationIconURL(for: web) == web)
    }
}
