import RishabhWMCore

func layoutTests() {
    let area = Rect(x: 0, y: 0, width: 1000, height: 800)

    test("tiles split evenly") {
        let tree = Node.container(.horizontal, .tiles, [.window(1), .window(2)])
        let rects = TreeLayout.windowRects(tree, in: area, settings: .default)
        expectEqual(rects[1], Rect(x: 0, y: 0, width: 500, height: 800))
        expectEqual(rects[2], Rect(x: 500, y: 0, width: 500, height: 800))
    }

    test("gaps apply inside and outside") {
        let tree = Node.container(.horizontal, .tiles, [.window(1), .window(2)])
        let settings = LayoutSettings(innerGap: 10, outerGap: 20, accordionPadding: 30)
        let rects = TreeLayout.windowRects(tree, in: area, settings: settings)
        expectEqual(rects[1], Rect(x: 20, y: 20, width: 475, height: 760))
        expectEqual(rects[2], Rect(x: 505, y: 20, width: 475, height: 760))
    }

    test("nested vertical split") {
        let tree = Node.container(.horizontal, .tiles, [
            .window(1),
            .container(.vertical, .tiles, [.window(2), .window(3)]),
        ])
        let rects = TreeLayout.windowRects(tree, in: area, settings: .default)
        expectEqual(rects[2], Rect(x: 500, y: 0, width: 500, height: 400))
        expectEqual(rects[3], Rect(x: 500, y: 400, width: 500, height: 400))
    }

    test("accordion stacks with padding") {
        let tree = Node.container(.horizontal, .accordion, [.window(1), .window(2), .window(3)])
        let rects = TreeLayout.windowRects(tree, in: area, settings: .default)
        expectEqual(rects[1], Rect(x: 0, y: 0, width: 970, height: 800))
        expectEqual(rects[2], Rect(x: 30, y: 0, width: 940, height: 800))
        expectEqual(rects[3], Rect(x: 30, y: 0, width: 970, height: 800))
    }

    test("weights change sizes") {
        let tree = Node.container(.horizontal, .tiles, [.window(1, weight: 3), .window(2, weight: 1)])
        let rects = TreeLayout.windowRects(tree, in: area, settings: .default)
        expectEqual(rects[1]?.width, 750)
    }
}
