import RishabhWMCore

private func h(_ kids: Node...) -> Node { .container(.horizontal, .tiles, kids) }
private func v(_ kids: Node...) -> Node { .container(.vertical, .tiles, kids) }
private func w(_ id: WindowID) -> Node { .window(id) }

private func moved(_ outcome: MoveOutcome) -> Node? {
    if case .moved(let tree) = outcome { return tree }
    return nil
}

func treeTests() {
    test("normalize flattens single-child containers and merges same orientation") {
        expectEqual(h(w(1), v(w(2))).normalized(), h(w(1), w(2)))
        expectEqual(h(w(1), h(w(2), w(3))).normalized().windows, [1, 2, 3])
        expectEqual(h(w(1), h(w(2), w(3))).normalized().children.count, 3)
        expectEqual(h(v(w(1), w(2))).normalized(), v(w(1), w(2)))
        expectEqual(h(w(1), v()).normalized(), h(w(1)))
    }

    test("remove keeps structure valid") {
        expectEqual(h(w(1), v(w(2), w(3))).removingWindow(3), h(w(1), w(2)))
        expectEqual(h(w(1)).removingWindow(1), h())
    }

    test("move swaps with sibling window") {
        expectEqual(moved(h(w(1), w(2), w(3)).moving(1, .right)), h(w(2), w(1), w(3)))
        expectEqual(moved(h(w(1), w(2), w(3)).moving(3, .left)), h(w(1), w(3), w(2)))
    }

    test("move at edge reports atEdge") {
        expectEqual(h(w(1), w(2)).moving(1, .left), .atEdge)
        expectEqual(h(w(1)).moving(1, .right), .atEdge)
        expectEqual(h(w(1)).moving(9, .right), .notFound)
    }

    test("move into sibling container") {
        expectEqual(moved(h(w(1), v(w(2), w(3))).moving(1, .right)), v(w(2), w(3), w(1)))
    }

    test("move pops out of nested container") {
        expectEqual(moved(h(w(1), v(w(2), w(3))).moving(3, .left)), h(w(1), w(3), w(2)))
        expectEqual(moved(h(w(1), v(w(2), w(3))).moving(3, .right)), h(w(1), w(2), w(3)))
    }

    test("move across orientation wraps root") {
        expectEqual(moved(h(w(1), w(2)).moving(1, .up)), v(w(1), w(2)))
        expectEqual(moved(h(w(1), w(2), w(3)).moving(3, .down)), v(h(w(1), w(2)), w(3)))
    }

    test("join-with groups neighbors into opposite container") {
        let joined = h(w(1), w(2), w(3)).joining(2, .right)
        expectEqual(joined?.children.count, 2)
        expectEqual(joined?.children[1].orientation, .vertical)
        expectEqual(joined?.children[1].windows, [2, 3])
        expect(h(w(1), w(2)).joining(1, .left) == nil, "nothing to the left")
        expect(h(w(1), w(2)).joining(1, .down) == nil, "parent is horizontal")
    }

    test("layout toggles") {
        expectEqual(h(w(1), w(2)).togglingTiles(for: 1), v(w(1), w(2)))
        expectEqual(h(w(1), w(2)).togglingAccordion(for: 1), .container(.horizontal, .accordion, [w(1), w(2)]))
        let accordion = Node.container(.horizontal, .accordion, [w(1), w(2)])
        expectEqual(accordion.togglingAccordion(for: 1), .container(.vertical, .accordion, [w(1), w(2)]))
        expectEqual(accordion.togglingTiles(for: 1), h(w(1), w(2)))
    }

    test("resize changes pixel share") {
        let tree = h(w(1), w(2)).resizing(1, by: 100, parentLength: 1000)
        let rects = tree.map { TreeLayout.windowRects($0, in: Rect(x: 0, y: 0, width: 1000, height: 500), settings: .default) }
        expectEqual(rects?[1]?.width.rounded(), 600)
        expectEqual(rects?[2]?.width.rounded(), 400)
        expect(h(w(1)).resizing(1, by: 50, parentLength: 1000) == nil, "single child cannot resize")
    }

    test("flatten puts everything in one row") {
        expectEqual(v(w(1), h(w(2), w(3))).flattened(), h(w(1), w(2), w(3)))
    }

    test("navigation picks tree neighbor") {
        let tree = h(w(1), v(w(2), w(3)))
        let rects = TreeLayout.windowRects(tree, in: Rect(x: 0, y: 0, width: 1000, height: 1000), settings: .default)
        expectEqual(tree.neighborWindow(of: 1, .right, rects: rects), 2)
        expectEqual(tree.neighborWindow(of: 3, .up, rects: rects), 2)
        expectEqual(tree.neighborWindow(of: 3, .left, rects: rects), 1)
        expectEqual(tree.neighborWindow(of: 1, .left, rects: rects), nil)
    }
}
