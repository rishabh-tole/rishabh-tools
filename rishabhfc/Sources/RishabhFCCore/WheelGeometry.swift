import Foundation

/// Hit-testing for the radial wheel: a center hub plus `segments` ring slices, clockwise from 12 o'clock.
/// Coordinates are relative to the wheel's center with y pointing up (AppKit's default).
public struct WheelGeometry: Equatable, Sendable {
    public let segments: Int
    public let radius: Double
    public let hub: Double
    /// Distance past the rim that still selects a slice, so a sloppy drop still lands.
    public let slack: Double

    public init(segments: Int, radius: Double, hub: Double, slack: Double) {
        self.segments = segments
        self.radius = radius
        self.hub = hub
        self.slack = slack
    }

    /// Width of one slice in radians.
    public var span: Double { segments > 0 ? 2 * .pi / Double(segments) : 2 * .pi }

    /// 0 for the hub, 1...segments for ring slices, nil when the point is outside the wheel.
    public func slot(atX x: Double, y: Double) -> Int? {
        let distance = (x * x + y * y).squareRoot()
        if distance > radius + slack { return nil }
        if segments == 0 || distance <= hub { return 0 }
        let clockwiseFromTop = positive(.pi / 2 - atan2(y, x))
        let index = Int(((clockwiseFromTop + span / 2) / span).rounded(.down)) % segments
        return index + 1
    }

    /// Middle angle of ring slice `index` (0-based), in radians, counter-clockwise from 3 o'clock.
    public func midAngle(ofSegment index: Int) -> Double {
        .pi / 2 - Double(index) * span
    }

    private func positive(_ angle: Double) -> Double {
        let wrapped = angle.truncatingRemainder(dividingBy: 2 * .pi)
        return wrapped < 0 ? wrapped + 2 * .pi : wrapped
    }
}
