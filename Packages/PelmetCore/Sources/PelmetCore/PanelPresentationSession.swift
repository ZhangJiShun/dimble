/// A visible panel is one presentation, not every background AX walk or
/// picture pass. Deliberate context changes and drags may rebuild it.
public struct PanelPresentationSession<Context: Equatable, Image> {
    private var context: Context?
    private var snapshot: PanelModel?
    private var images: [PanelTile: (image: Image, isFinal: Bool)] = [:]

    public init() {}

    public mutating func reset() {
        context = nil
        snapshot = nil
        images.removeAll(keepingCapacity: true)
    }

    public mutating func stabilize(_ proposed: PanelModel, context: Context, editing: Bool = false) -> PanelModel {
        if editing {
            reset()
            return proposed
        }
        if self.context != context {
            reset()
            self.context = context
        }
        if let snapshot { return snapshot }
        snapshot = proposed
        return proposed
    }

    /// The art a tile keeps for the whole presentation, so it doesn't swap
    /// under the pointer. A stand-in is the one exception: when the real
    /// picture (`isFinal`) arrives, it replaces the stand-in once.
    public mutating func image(for tile: PanelTile, proposed: Image, isFinal: Bool = false) -> Image {
        if let held = images[tile], held.isFinal || !isFinal { return held.image }
        images[tile] = (proposed, isFinal)
        return proposed
    }

    /// Drop tiles that are known to be gone (an app that quit, an icon its
    /// app turned off) from the frozen snapshot. A tile merely missing from
    /// one rebuild stays; only a deliberate verdict calls this.
    public mutating func forget(_ gone: Set<PanelTile>) {
        guard var kept = snapshot, !gone.isEmpty else { return }
        for index in kept.sections.indices {
            kept.sections[index].tiles.removeAll { gone.contains($0) }
        }
        if kept.bestMatch.map(gone.contains) == true { kept.bestMatch = nil }
        snapshot = kept
        for tile in gone { images[tile] = nil }
    }
}
