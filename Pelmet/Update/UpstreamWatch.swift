import AppKit
import SwiftUI
import PelmetCore
import PelmetEngine

/// Fork-only (see AGENTS.md §3): Sparkle is switched off so upstream's
/// build can never replace this one, but a newer upstream release still
/// needs to be known about — it is merged in, not installed. Once a day the
/// upstream appcast is read; a newer stable release lights the chevron's
/// dot until About has been opened, and About says what to do.
@MainActor
@Observable
final class UpstreamWatch {
    static let shared = UpstreamWatch()

    /// The same feed upstream's Sparkle reads; nothing is downloaded from it.
    static let feedURL = URL(string: "https://fif7y.github.io/updates/pliss/appcast.xml")!
    static let releasesURL = URL(string: "https://github.com/fif7y/dimble/releases")!

    /// Upstream's newer stable release, nil while this build is current.
    private(set) var newer: UpstreamFeed.Release?
    private(set) var checking = false
    private(set) var lastChecked: Date?
    /// The last check failed (offline, feed moved): About says so.
    private(set) var failed = false

    /// The upstream build this fork is based on (merging upstream brings
    /// its CURRENT_PROJECT_VERSION along).
    let baseBuild = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    let baseVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"

    /// AppKit mirror for the chevron's dot.
    @ObservationIgnored var onChange: (() -> Void)?

    private static let seenKey = "dimble.upstreamSeenBuild"
    @ObservationIgnored private var timer: Timer?

    /// Lit until About has shown this release once.
    var wantsDot: Bool {
        guard let newer else { return false }
        return UserDefaults.standard.integer(forKey: Self.seenKey) < newer.build
    }

    func start() {
        guard timer == nil else { return }
        // A minute after launch, then daily; generous tolerance = coalesced wakeups.
        let first = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { _ in
            Task { @MainActor in await UpstreamWatch.shared.check() }
        }
        first.tolerance = 30
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
            Task { @MainActor in await UpstreamWatch.shared.check() }
        }
        timer?.tolerance = 60 * 60
    }

    /// About has been opened with the notice on screen: the dot goes.
    func acknowledge() {
        guard let newer, wantsDot else { return }
        UserDefaults.standard.set(newer.build, forKey: Self.seenKey)
        onChange?()
    }

    func check() async {
        guard !checking else { return }
        checking = true
        defer { checking = false; lastChecked = Date() }
        var request = URLRequest(url: Self.feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpShouldHandleCookies = false
        do {
            let (data, response) = try await URLSession(configuration: .ephemeral).data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                failed = true
                PelmetLog.log("upstream: feed answered \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return
            }
            let appcast = String(decoding: data, as: UTF8.self)
            failed = UpstreamFeed.latestStable(in: appcast) == nil
            let found = UpstreamFeed.newer(in: appcast, thanBuild: baseBuild)
            PelmetLog.log("upstream: checked, base \(baseVersion) (\(baseBuild)), newer \(found.map { "\($0.version) (\($0.build))" } ?? "none")")
            if found != newer {
                newer = found
                onChange?()
            }
        } catch {
            failed = true
            PelmetLog.log("upstream: check failed — \(error.localizedDescription)")
        }
    }
}

/// About's update row in the fork: what upstream has, never an install.
struct UpstreamRow: View {
    @State private var watch = UpstreamWatch.shared

    var body: some View {
        VStack(spacing: 6) {
            if let newer = watch.newer {
                AccentChipButton(text: "Upstream released \(newer.version)", symbol: "arrow.triangle.merge") {
                    NSWorkspace.shared.open(UpstreamWatch.releasesURL)
                }
                Text("This build is based on \(watch.baseVersion). Merge upstream to get it — don't install it over this one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            } else if watch.checking {
                HStack(spacing: 7) {
                    ProgressView().controlSize(.small)
                    Text("Checking upstream…")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            } else if watch.lastChecked != nil, !watch.failed {
                StatusChip(text: "In sync with upstream \(watch.baseVersion)", symbol: "checkmark.seal.fill", tint: .green)
            } else {
                TintChipButton(text: watch.failed ? "Couldn't reach upstream — try again" : "Check upstream",
                               symbol: "arrow.triangle.2.circlepath") {
                    Task { await watch.check() }
                }
            }
        }
        .onAppear { watch.acknowledge() }
        .onChange(of: watch.newer) { watch.acknowledge() }
    }
}
