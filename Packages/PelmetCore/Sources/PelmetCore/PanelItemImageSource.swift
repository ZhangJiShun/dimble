import Foundation

/// App tiles use native artwork from the installed app, independently of
/// transient menu bar positions, screenshots and launcher symbol overrides.
public enum PanelItemImageSource: Equatable, Sendable {
    case appIcon(String)
    case systemItem
    case unavailable

    public static func resolve(for item: ItemID, extras: [ExtraItemSpec]) -> Self {
        guard let owner = item.bundleID else { return .systemItem }
        if PelmetBundle.ownIDs.contains(owner), item.isPelmetAppLauncher,
           case .status(_, let title) = item.parsed {
            guard let bundle = extras.first(where: { $0.kind == .appLauncher && $0.itemTitle == title })?.bundleID,
                  !bundle.isEmpty else { return .unavailable }
            return .appIcon(bundle)
        }
        if PelmetBundle.ownIDs.contains(owner) || owner == PelmetBundle.agentID
            || owner == PelmetBundle.systemUIServerID || owner == PelmetBundle.textInputAgentID {
            return .systemItem
        }
        return .appIcon(owner)
    }

    /// Embedded browsers/helpers carry their own generic app icon. Use the
    /// outer application that owns them. Inspect components once, without
    /// filesystem queries or an unbounded parent-directory walk.
    public static func applicationIconURL(for bundleURL: URL) -> URL {
        guard bundleURL.isFileURL else { return bundleURL }
        let parts = bundleURL.standardizedFileURL.pathComponents
        guard let index = parts.indices.first(where: { index in
            parts[index].lowercased().hasSuffix(".app")
                && (index == parts.count - 1 || parts[index + 1] == "Contents")
        }), index < parts.count - 1 else { return bundleURL }
        return URL(fileURLWithPath: NSString.path(withComponents: Array(parts.prefix(index + 1))))
    }
}
