import Foundation
import RishabhFCCore

func wheelTests() {
    let wheel = WheelGeometry(segments: 6, radius: 100, hub: 30, slack: 20)

    test("center is slot 0") {
        expectEqual(wheel.slot(atX: 0, y: 0), 0)
        expectEqual(wheel.slot(atX: 10, y: -20), 0)
    }

    test("ring slots go clockwise from 12 o'clock") {
        expectEqual(wheel.slot(atX: 0, y: 70), 1)       // top
        expectEqual(wheel.slot(atX: 60, y: 35), 2)      // upper right
        expectEqual(wheel.slot(atX: 60, y: -35), 3)     // lower right
        expectEqual(wheel.slot(atX: 0, y: -70), 4)      // bottom
        expectEqual(wheel.slot(atX: -60, y: -35), 5)    // lower left
        expectEqual(wheel.slot(atX: -60, y: 35), 6)     // upper left
    }

    test("a little past the rim still counts, far away does not") {
        expectEqual(wheel.slot(atX: 0, y: 115), 1)
        expectEqual(wheel.slot(atX: 0, y: 125), nil)
    }

    test("one choice is all center") {
        let solo = WheelGeometry(segments: 0, radius: 100, hub: 30, slack: 20)
        expectEqual(solo.slot(atX: 0, y: 90), 0)
        expectEqual(solo.slot(atX: 0, y: 130), nil)
    }

    test("segment middles point where the labels go") {
        expect(abs(wheel.midAngle(ofSegment: 0) - .pi / 2) < 1e-9)
        expect(abs(wheel.midAngle(ofSegment: 3) - -.pi / 2) < 1e-9)
    }
}

func namingTests() {
    let dir = URL(fileURLWithPath: "/tmp/x")

    test("output goes beside the source with the new extension") {
        let url = OutputName.unique(in: dir, base: "photo", ext: "png") { _ in false }
        expectEqual(url.path, "/tmp/x/photo.png")
    }

    test("never overwrites: numbers like Finder") {
        let taken: Set<String> = ["/tmp/x/photo.png", "/tmp/x/photo 2.png"]
        let url = OutputName.unique(in: dir, base: "photo", ext: "png") { taken.contains($0.path) }
        expectEqual(url.path, "/tmp/x/photo 3.png")
    }

    test("empty extension is a folder name") {
        expectEqual(OutputName.unique(in: dir, base: "backup", ext: "") { _ in false }.path, "/tmp/x/backup")
    }

    test("base name strips double extensions") {
        expectEqual(OutputName.base(of: "backup.tar.gz"), "backup")
        expectEqual(OutputName.base(of: "my.photo.jpg"), "my.photo")
        expectEqual(OutputName.base(of: "README"), "README")
    }
}
