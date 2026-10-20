extension Node {
    /// AeroSpace-style focus: climb to the nearest ancestor running in `direction` that has a
    /// neighbor branch, then pick the window in that branch closest to the current one.
    public func neighborWindow(of id: WindowID, _ direction: Direction, rects: [WindowID: Rect]) -> WindowID? {
        guard let path = path(of: id) else { return nil }
        for depth in stride(from: path.count - 1, through: 0, by: -1) {
            let ancestorPath = Array(path[0..<depth])
            guard let ancestor = node(at: ancestorPath), ancestor.orientation == direction.orientation else { continue }
            let neighbor = direction.isForward ? path[depth] + 1 : path[depth] - 1
            guard ancestor.children.indices.contains(neighbor) else { continue }
            let candidates = ancestor.children[neighbor].windows
            return Navigation.closest(candidates, to: rects[id], rects: rects) ?? candidates.first
        }
        return nil
    }
}

public enum Navigation {
    public static func closest(_ candidates: [WindowID], to origin: Rect?, rects: [WindowID: Rect]) -> WindowID? {
        guard let origin else { return nil }
        return candidates
            .compactMap { id in rects[id].map { (id, $0.distanceBetweenCenters(origin)) } }
            .min { $0.1 < $1.1 }?
            .0
    }

    /// The window right at the edge you enter from when moving in `direction` (leftmost when moving
    /// right, ...), ties broken by closeness to `origin` across the other axis.
    public static func edgeWindow(_ candidates: [WindowID], enteringFrom direction: Direction, near origin: Rect?, rects: [WindowID: Rect]) -> WindowID? {
        let edge: (Rect) -> Double = {
            switch direction {
            case .right: return $0.minX
            case .left: return -$0.maxX
            case .down: return $0.minY
            case .up: return -$0.maxY
            }
        }
        let cross: (Rect) -> Double = { rect in
            guard let origin else { return 0 }
            return direction.orientation == .horizontal ? abs(rect.midY - origin.midY) : abs(rect.midX - origin.midX)
        }
        return candidates
            .compactMap { id in rects[id].map { (id, edge($0), cross($0)) } }
            .min { ($0.1, $0.2) < ($1.1, $1.2) }?
            .0
    }

    /// Index of the nearest frame lying beyond `origin` in `direction`.
    public static func nearest(_ direction: Direction, from origin: Rect, among frames: [Rect]) -> Int? {
        frames.indices
            .filter { frames[$0] != origin && direction.isBeyond(frames[$0], from: origin) }
            .min { frames[$0].distanceBetweenCenters(origin) < frames[$1].distanceBetweenCenters(origin) }
    }
}
