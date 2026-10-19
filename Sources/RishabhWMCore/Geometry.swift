/// Rectangle in global screen coordinates: origin at top-left of the primary display, y grows downward
/// (the coordinate space the Accessibility API uses).
public struct Rect: Equatable, Hashable, CustomStringConvertible {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double { x }
    public var maxX: Double { x + width }
    public var minY: Double { y }
    public var maxY: Double { y + height }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }

    public func insetBy(_ amount: Double) -> Rect {
        Rect(
            x: x + amount,
            y: y + amount,
            width: max(0, width - 2 * amount),
            height: max(0, height - 2 * amount)
        )
    }

    public func length(along orientation: Orientation) -> Double {
        orientation == .horizontal ? width : height
    }

    public func contains(x px: Double, y py: Double) -> Bool {
        px >= minX && px < maxX && py >= minY && py < maxY
    }

    public func intersects(_ other: Rect) -> Bool {
        minX < other.maxX && other.minX < maxX && minY < other.maxY && other.minY < maxY
    }

    /// Same relative spot in `target` as this rect has in `source`, shrunk to fit if needed.
    public func moved(from source: Rect, to target: Rect) -> Rect {
        let w = min(width, target.width)
        let h = min(height, target.height)
        let fx = source.width > width ? (x - source.x) / (source.width - width) : 0
        let fy = source.height > height ? (y - source.y) / (source.height - height) : 0
        let clamp = { (value: Double) in min(1, max(0, value)) }
        return Rect(
            x: target.x + clamp(fx) * (target.width - w),
            y: target.y + clamp(fy) * (target.height - h),
            width: w,
            height: h
        )
    }

    public func isClose(to other: Rect, tolerance: Double = 1.5) -> Bool {
        abs(x - other.x) <= tolerance && abs(y - other.y) <= tolerance
            && abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
    }

    public func distanceBetweenCenters(_ other: Rect) -> Double {
        let dx = midX - other.midX
        let dy = midY - other.midY
        return (dx * dx + dy * dy).squareRoot()
    }

    public var rounded: Rect {
        Rect(x: x.rounded(), y: y.rounded(), width: width.rounded(), height: height.rounded())
    }

    public var description: String { "(\(Int(x)),\(Int(y)) \(Int(width))x\(Int(height)))" }
}

public enum Orientation: Equatable {
    case horizontal
    case vertical

    public var opposite: Orientation { self == .horizontal ? .vertical : .horizontal }
}

public enum Direction: String, CaseIterable, Equatable {
    case left, down, up, right

    public var orientation: Orientation {
        (self == .left || self == .right) ? .horizontal : .vertical
    }

    /// Right and down move toward higher child indices / larger coordinates.
    public var isForward: Bool { self == .right || self == .down }

    /// True when `candidate` lies beyond `origin` in this direction.
    public func isBeyond(_ candidate: Rect, from origin: Rect, tolerance: Double = 2) -> Bool {
        switch self {
        case .left: return candidate.maxX <= origin.minX + tolerance
        case .right: return candidate.minX >= origin.maxX - tolerance
        case .up: return candidate.maxY <= origin.minY + tolerance
        case .down: return candidate.minY >= origin.maxY - tolerance
        }
    }
}
