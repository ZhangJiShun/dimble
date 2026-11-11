import Testing
@testable import PelmetCore

struct UpstreamFeedTests {
    private func item(_ version: String, _ build: Int, channel: String? = nil) -> String {
        """
        <item>
            <title>\(version)</title>
            <sparkle:version>\(build)</sparkle:version>
            <sparkle:shortVersionString>\(version)</sparkle:shortVersionString>
            \(channel.map { "<sparkle:channel>\($0)</sparkle:channel>" } ?? "")
        </item>
        """
    }

    private func feed(_ items: String...) -> String {
        "<rss><channel>\(items.joined())</channel></rss>"
    }

    @Test func betasAreSkipped() {
        let appcast = feed(
            item("0.4.0-beta.3", 92, channel: "beta"),
            item("0.4.0-beta.2", 91, channel: "beta"),
            item("0.3.5", 90)
        )
        #expect(UpstreamFeed.latestStable(in: appcast) == .init(version: "0.3.5", build: 90))
        #expect(UpstreamFeed.newer(in: appcast, thanBuild: 90) == nil)
    }

    @Test func aNewerStableReleaseIsReported() {
        let appcast = feed(item("0.3.5", 90), item("0.4.0", 93), item("0.4.1-beta.1", 94, channel: "beta"))
        #expect(UpstreamFeed.newer(in: appcast, thanBuild: 90) == .init(version: "0.4.0", build: 93))
    }

    @Test func orderInTheFeedDoesNotMatter() {
        let appcast = feed(item("0.3.4", 89), item("0.4.0", 93), item("0.3.5", 90))
        #expect(UpstreamFeed.latestStable(in: appcast)?.build == 93)
    }

    @Test func brokenOrEmptyFeedsYieldNothing() {
        #expect(UpstreamFeed.latestStable(in: "") == nil)
        #expect(UpstreamFeed.latestStable(in: "<html>404</html>") == nil)
        #expect(UpstreamFeed.latestStable(in: feed("<item><sparkle:version>x</sparkle:version></item>")) == nil)
        #expect(UpstreamFeed.latestStable(in: "<item><sparkle:version>95") == nil)
    }
}
