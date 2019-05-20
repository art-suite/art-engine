Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'
StateEpochTestHelper = require '../../StateEpochTestHelper'


{inspect, log, isArray, min, max} = Foundation
{point, matrix} = Atomic
{renderTest, stateEpochTest} = StateEpochTestHelper

{Element, RectangleElement} = require 'art-engine/Factories'

module.exports = suite:
  "parent relative": ->

    stateEpochTest "layout is applied onNextReady", ->
      parent = Element name:"parent", size: 256
      child  = Element name:"child",  size: ps:1
      parent.addChild child

      assert.ok child.sizeChanged

      ->
        assert.eq parent.currentSize, point 256
        assert.eq child.currentSize, point 256

    stateEpochTest "undefined layout results in default layout", ->
      Element
        size: 123
        child1 = Element size: undefined  # should default to ps:1
        child2 = Element size: null       # should be set to 0
        child3 = Element size: false      # should be set to 0
        child4 = Element size: 0          # should be set to 0

      ->
        assert.eq child1.currentSize, point(123), "undefined"
        assert.eq child2.currentSize, point(123), "null"
        assert.eq child3.currentSize, point(0), "false"
        assert.eq child4.currentSize, point(0), "0"

    stateEpochTest "layout location is not truncated", ->
      parent = Element name:"parent", size: 3
      child = Element name:"child", location: ps:.5
      parent.addChild child

      ->
        assert.eq child.currentLocation, point 1.5

    stateEpochTest "layout location is truncated after applying the axis", ->
      parent = Element name:"parent", size: 3,
        child = Element name:"child", axis: .5, location: ps:.5
      -> assert.eq child.currentLocation, point 1.5


    stateEpochTest "layout size is not rounded", ->
      parent = Element name:"parent", size: 3.2
      -> assert.eq parent.currentSize, point 3.2

    # stateEpochTest "layout is forceAllLayout", ->
    #   child = Element name:"child", size: x:10
      # -> assert.eq child.size.hasFullLayout, true

    stateEpochTest "layout with axis:1", ->
      parent = Element
        size: 256
        Element
          size: ps:1
          child = Element
            axis: 1
            size: 50
            location: ps:1

      ->
        assert.eq parent.currentSize, point 256
        assert.eq child.currentLocation, point 256

    stateEpochTest "changing parent size results in up-to-date children layouts onNextReady", ->
      grandParent = Element size: 456,
        parent = Element {}, child = Element()

      ->
        assert.eq parent.currentSize, point 456
        assert.eq child.currentSize, point 456

        grandParent.size = 123

        ->
          assert.eq parent.currentSize, point 123
          assert.eq child.currentSize, point 123

    stateEpochTest "change in parent results in up-to-date children layouts onNextReady", ->
      parent1 = Element size:123,
        child = Element()
      parent2 = Element size:456

      ->
        assert.eq parent1.currentSize, point 123
        assert.eq child.currentSize, point 123

        child.parent = parent2

        ->
          assert.eq parent2.currentSize, point 456
          assert.eq child.currentSize, point 456

    # this tests an exception-throwing bug that only shows up with 4 tiers in StateEpoch#recomputeLayouts
    stateEpochTest "four tiered layout", ->
      root = Element
        size: 200
        Element {},
          Element {},
            leaf = Element()

      ->
        root.size = 150

        ->
          assert.eq leaf.currentSize, point 150

  "children relative": ->

    stateEpochTest "child location == 0", ->
      root = Element
        size: cs: 1
        Element size:25
      ->
        assert.eq root.currentSize, point 25

    stateEpochTest "child location > 0", ->
      root = Element
        size: cs: 1
        Element location:10, size:25

      ->
        assert.eq root.currentSize, point 35

    stateEpochTest "two children with location > 0", ->
      root = Element
        size: cs: 1
        Element size:21, location: x:20
        Element size:22, location: y:30

      ->
        assert.eq root.currentSize, point 41, 52

    stateEpochTest "child layoutLocationParentCircular", ->
      parent = Element
        name: "parent"
        size: cs: 1
        Element name: "child", size: 25, location: ps: .5

      ->
        assert.eq parent.currentSize, point 25

    renderTest "child layoutSizeParentCircular",
      render: -> Element
        key: "a"
        size: cs: 1
        b = RectangleElement color: "red",  key: "b", size: ps: 1
        c = RectangleElement color: "blue", key: "c", location: 10, size: 25

      test: (a) ->
        [b, c] = a.children
        assert.eq a.currentSize, point 35
        assert.eq b.currentSize, point 35
        assert.eq c.currentSize, point 25

    renderTest "child layoutSizeParentCircular with inFlow override",
      render: -> Element
        key: "a"
        size: cs: 1
        b = RectangleElement inFlow: false, color: "red",  key: "b", size: ps: 1
        c = RectangleElement color: "blue", key: "c", location: 10, size: 25

      test: (a) ->
        [b, c] = a.children
        assert.eq a.currentSize, point 35
        assert.eq b.currentSize, point 35
        assert.eq c.currentSize, point 25

    stateEpochTest "childrenLayout: area", ->
      root = Element
        size: cs: 1
        el1 = Element location:10,  size:50
        el2 = Element location:100, size:25

      ->
        assert.eq root.currentSize, point 125
        el1.location = point 200, 10

        ->
          assert.eq root.currentSize, point 250, 125

    stateEpochTest "childrenLayout: custom function layout with max", ->
      a = Element
        key: "a"
        size:
          x: (ps, cs) -> cs.x + 10
          y: (ps, cs) -> max 50, cs.y + 10
        b = Element key: "b", inFlow: false
        c = Element
          key: "c"
          location: ps: .5
          size: h:30, w:100

      ->
        assert.eq a.currentSize, point 110, 50
        assert.eq b.currentSize, a.currentSize
        assert.eq c.currentSize, point 100, 30
        assert.eq c.currentLocation, point a.currentSize.div 2

        c.size = point 200, 100

        ->
          assert.eq a.currentSize, point 210, 110
          assert.eq b.currentSize, a.currentSize
          assert.eq c.currentSize, point 200, 100
          assert.eq c.currentLocation, point a.currentSize.div 2

    stateEpochTest "childrenLayout parent-height-child-relative and child-width-parent-relative", ->
      root = Element
        size: w: 100, hch: 1
        el = Element size: h:30

      ->
        assert.eq root.currentSize, point 100, 30
        assert.eq el.currentSize, root.currentSize

    stateEpochTest "childrenLayout: area 2", ->
      a = Element
        size: w:200, hch:1
        b = Element
          size: h:300
      ->
        assert.eq a.currentSize, point 200, 300
        assert.eq b.currentSize, point 200, 300

    stateEpochTest "removed child doesn't re-layout", ->
      a = Element
        size: w:456, hch:1
        b = Element
          size: h:300
      ->
        assert.eq a.currentSize, point 456, 300
        assert.eq b.currentSize, point 456, 300
        a.children = []
        ->
          assert.eq b.currentSize, point 456, 300

    stateEpochTest "regression 1", ->
      a = Element
        key: "a"
        size: 100
        b = Element
          key: "b"
          size:
            ww: 1
            h: (ps, cs) -> min cs.y, ps.y

      ->
        assert.eq b.currentSize, point 100, 0

  regressions: ->
    stateEpochTest "regression 2a - more than one nesting of an element which is both parent and child relative breaks", ->
      ###
      TODO
      To truely resolve this we need SOME way to force
      layouts that appear parent-circular to layout in the first pass
      with the "best parentSize available."

      For right now, using the "max" parameter seems like the best solution.
      1) that's the only use-case I know
      2) It already supports a near-fully functional solution:
        You can actually get pretty complex by adding a layout function
        both to the base layout and the max layout.
      ###
      testNestedSizeLayout =
        hch: 1
        # THIS SUCCEEDS because it is defined to be not parent-circular
        wcw: 1, max: ww: 1

      a = Element
        key: "a"
        size:
          hch:1
          w: 100

        b = Element
          key: "b"
          size: testNestedSizeLayout

          c = Element
            key: "c"
            size: testNestedSizeLayout
            Element size: 25, key: "d"

          d = Element
            key: "c"
            size: testNestedSizeLayout
            Element size: 30, key: "d"

      ->
        assert.eq d.currentSize, point(30), "d.currentSize"
        assert.eq c.currentSize, point(25), "c.currentSize"
        assert.eq b.currentSize, point(30), "b.currentSize"
        assert.eq a.currentSize, point 100, 30

    renderTest "regression 2b - more than one nesting of an element which is both parent and child relative breaks",
      render: ->
        ###
        TODO
        To truely resolve this we need SOME way to force
        layouts that appear parent-circular to layout in the first pass
        with the "best parentSize available."

        For right now, using the "max" parameter seems like the best solution.
        1) that's the only use-case I know
        2) It already supports a near-fully functional solution:
          You can actually get pretty complex by adding a layout function
          both to the base layout and the max layout.
        ###
        testNestedSizeLayout =
          hch: 1
          # because this detects as parent-circular when both parent and child have this layout
          # any child with this layout will not contribute to it's parent's size computation
          w: (ps, cs) -> min ps.w, cs.w

        Element
          key: "a"
          size:
            hch:  1
            w:    100

          Element
            key: "beta"
            size: testNestedSizeLayout

            Element
              key: "gamma"
              size: testNestedSizeLayout
              Element size: 25, drawOrder: fill: "red"

            Element
              key: "delta"
              size: testNestedSizeLayout
              Element size: 30, drawOrder: fill: "red"

      test: (a) ->
        [b] = a.find 'beta'
        [c] = a.find 'gamma'
        [d] = a.find 'delta'
        assert.eq d.currentSize, point(30), "d.currentSize"
        assert.eq c.currentSize, point(25), "c.currentSize"
        assert.eq b.currentSize, point(30), "b.currentSize"
        assert.eq a.currentSize, point 100, 30

    stateEpochTest "regression 3", ->
      gp = Element
        size: w:150, hch: 1
        p1 = Element
          size: cs: 1, max: ww: 1
          c1 = Element size: 50

        p2 = Element
          size: cs: 1, max: ww: 1
          c2 = Element size: 200
      ->
        assert.eq gp.currentSize, point 150, 200
        assert.eq p1.currentSize, point 50
        assert.eq p2.currentSize, point 150, 200

