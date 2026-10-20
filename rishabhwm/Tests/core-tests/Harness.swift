import Foundation

/// Minimal test harness: XCTest / swift-testing need full Xcode, this runs with Command Line Tools.
final class Harness {
    static let shared = Harness()
    private(set) var failures: [String] = []
    private(set) var count = 0
    private var current = ""

    func test(_ name: String, _ body: () -> Void) {
        current = name
        count += 1
        body()
    }

    func expect(_ condition: Bool, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
        guard !condition else { return }
        failures.append("✗ \(current) (\(URL(fileURLWithPath: "\(file)").lastPathComponent):\(line)) \(message())")
    }

    func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) {
        expect(actual == expected, "\n    got:      \(actual)\n    expected: \(expected)", file: file, line: line)
    }

    func finish() -> Never {
        failures.forEach { print($0) }
        print(failures.isEmpty ? "✓ all \(count) tests passed" : "\(failures.count) failure(s) in \(count) tests")
        exit(failures.isEmpty ? 0 : 1)
    }
}

func test(_ name: String, _ body: () -> Void) { Harness.shared.test(name, body) }

func expect(_ condition: Bool, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    Harness.shared.expect(condition, message(), file: file, line: line)
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) {
    Harness.shared.expectEqual(actual, expected, file: file, line: line)
}
