import Foundation

/// Fork-only: reads the upstream Sparkle appcast to tell whether upstream
/// shipped a newer stable release than the one this build is based on.
/// Nothing is installed from it — the fork syncs upstream by merging.
public enum UpstreamFeed {
    public struct Release: Equatable, Sendable {
        /// "0.4.0" — the appcast's `sparkle:shortVersionString`.
        public var version: String
        /// The build number (`sparkle:version`), the one Sparkle compares.
        public var build: Int

        public init(version: String, build: Int) {
            self.version = version
            self.build = build
        }
    }

    /// The highest-build stable item: items that carry a `sparkle:channel`
    /// (beta) are skipped, as are items without a numeric build.
    public static func latestStable(in appcast: String) -> Release? {
        var best: Release?
        var rest = appcast[...]
        while let open = rest.range(of: "<item>") {
            guard let close = rest.range(of: "</item>", range: open.upperBound..<rest.endIndex) else { break }
            let item = rest[open.upperBound..<close.lowerBound]
            rest = rest[close.upperBound...]
            if value(of: "sparkle:channel", in: item) != nil { continue }
            guard let build = value(of: "sparkle:version", in: item).flatMap({ Int($0) }),
                  let version = value(of: "sparkle:shortVersionString", in: item) else { continue }
            if build > (best?.build ?? Int.min) { best = Release(version: version, build: build) }
        }
        return best
    }

    /// Upstream's release, when it is newer than the build this fork is based on.
    public static func newer(in appcast: String, thanBuild base: Int) -> Release? {
        guard let latest = latestStable(in: appcast), latest.build > base else { return nil }
        return latest
    }

    private static func value(of tag: String, in item: Substring) -> String? {
        guard let open = item.range(of: "<\(tag)>"),
              let close = item.range(of: "</\(tag)>", range: open.upperBound..<item.endIndex) else { return nil }
        let text = item[open.upperBound..<close.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
