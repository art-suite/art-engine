Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'
StateEpochTestHelper = require '../state_epoch_test_helper'


{inspect, log, isArray, min, max} = Foundation
{point, matrix} = Atomic
{stateEpochTest} = StateEpochTestHelper

{Element} = Engine

suite "Art.Engine.Core.layout.pointLayout.parent relative", ->

  stateEpochTest "layout is applied onNextReady", ->
    parent = new Element name:"parent", size: 256
    child  = new Element name:"child",  size: ps:1
    parent.addChild child

    assert.ok child.sizeChanged

    ->
      assert.eq parent.currentSize, point 256
      assert.eq child.currentSize, point 256

  stateEpochTest "undefined layout results in default layout", ->
    new Element
      size: 123
      child1 = new Element size: undefined  # should default to ps:1
      child2 = new Element size: null       # should be set to 0
      child3 = new Element size: false      # should be set to 0
      child4 = new Element size: 0          # should be set to 0

    ->
      assert.eq child1.currentSize, point(123), "undefined"
      assert.eq child2.currentSize, point(0), "null"
      assert.eq child3.currentSize, point(0), "false"
      assert.eq child4.currentSize, point(0), "0"

  stateEpochTest "layout location is not truncated", ->
    parent = new Element name:"parent", size: 3
    child = new Element name:"child", location: ps:.5
    parent.addChild child

    ->
      assert.eq child.currentLocation, point 1.5

  stateEpochTest "layout location is truncated after applying the axis", ->
    parent = new Element name:"parent", size: 3,
      child = new Element name:"child", axis: .5, location: ps:.5
    -> assert.eq child.currentLocation, point 1.5


  stateEpochTest "layout size is not rounded", ->
    parent = new Element name:"parent", size: 3.2
    -> assert.eq parent.currentSize, point 3.2

  # stateEpochTest "layout is forceAllLayout", ->
  #   child = new Element name:"child", size: x:10
    # -> assert.eq child.size.hasFullLayout, true

  stateEpochTest "layout with axis:1", ->
    parent = new Element
      size: 256
      new Element
        size: ps:1
        child = new Element
          axis: 1
          size: 50
          location: ps:1

    ->
      assert.eq parent.currentSize, point 256
      assert.eq child.currentLocation, point 256

  stateEpochTest "changing parent size results in up-to-date children layouts onNextReady", ->
    grandParent = new Element size: 456,
      parent = new Element {}, child = new Element()

    ->
      assert.eq parent.currentSize, point 456
      assert.eq child.currentSize, point 456

      grandParent.size = 123

      ->
        assert.eq parent.currentSize, point 123
        assert.eq child.currentSize, point 123

  stateEpochTest "change in parent results in up-to-date children layouts onNextReady", ->
    parent1 = new Element size:123,
      child = new Element()
    parent2 = new Element size:456

    ->
      assert.eq parent1.currentSize, point 123
      assert.eq child.currentSize, point 123

      child.parent = parent2

      ->
        assert.eq parent2.currentSize, point 456
        assert.eq child.currentSize, point 456

  # this tests an exception-throwing bug that only shows up with 4 tiers in StateEpoch#recomputeLayouts
  stateEpochTest "four tiered layout", ->
    root = new Element
      size: 200
      new Element {},
        new Element {},
          leaf = new Element()

    ->
      root.size = 150

      ->
        assert.eq leaf.currentSize, point 150

suite "Art.Engine.Core.layout.pointLayout.children relative", ->

  stateEpochTest "child location == 0", ->
    root = new Element
      size: cs: 1
      new Element size:25
    ->
      assert.eq root.currentSize, point 25

  stateEpochTest "child location > 0", ->
    root = new Element
      size: cs: 1
      new Element location:10, size:25

    ->
      assert.eq root.currentSize, point 35

  stateEpochTest "two children with location > 0", ->
    root = new Element
      size: cs: 1
      new Element size:21, location: x:20
      new Element size:22, location: y:30

    ->
      assert.eq root.currentSize, point 41, 52

  stateEpochTest "child layoutLocationParentCircular", ->
    parent = new Element
      name: "parent"
      size: cs: 1
      new Element name: "child", size: 25, location: ps: .5

    ->
      assert.eq parent.currentSize, point 25

  stateEpochTest "child layoutSizeParentCircular", ->
    a = new Element
      key: "a"
      size: cs: 1
      b = new Element key: "b", size: ps:1
      c = new Element key: "c", location: 10, size: 25

    ->
      assert.eq a.currentSize, point 35
      assert.eq b.currentSize, point 35
      assert.eq c.currentSize, point 25

  stateEpochTest "childrenLayout: area", ->
    root = new Element
      size: cs: 1
      el1 = new Element location:10,  size:50
      el2 = new Element location:100, size:25

    ->
      assert.eq root.currentSize, point 125
      el1.location = point 200, 10

      ->
        assert.eq root.currentSize, point 250, 125

  stateEpochTest "childrenLayout: custom function layout with max", ->
    a = new Element
      key: "a"
      size:
        x: (ps, cs) -> cs.x + 10
        y: (ps, cs) -> max 50, cs.y + 10
      b = new Element key: "b", inFlow: false
      c = new Element
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
    root = new Element
      size: w: 100, hch: 1
      el = new Element size: h:30

    ->
      assert.eq root.currentSize, point 100, 30
      assert.eq el.currentSize, root.currentSize

  stateEpochTest "childrenLayout: area 2", ->
    a = new Element
      size: w:200, hch:1
      b = new Element
        size: h:300
    ->
      assert.eq a.currentSize, point 200, 300
      assert.eq b.currentSize, point 200, 300

  stateEpochTest "removed child doesn't re-layout", ->
    a = new Element
      size: w:456, hch:1
      b = new Element
        size: h:300
    ->
      assert.eq a.currentSize, point 456, 300
      assert.eq b.currentSize, point 456, 300
      a.children = []
      ->
        assert.eq b.currentSize, point 456, 300

  stateEpochTest "regression 1", ->
    a = new Element
      key: "a"
      size: 100
      b = new Element
        key: "b"
        size:
          ww: 1
          h: (ps, cs) -> min cs.y, ps.y

    ->
      assert.eq b.currentSize, point 100, 0

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

    a = new Element
      key: "a"
      size:
        hch:1
        w: 100

      b = new Element
        key: "b"
        size: testNestedSizeLayout

        c = new Element
          key: "c"
          size: testNestedSizeLayout
          new Element size: 25, key: "d"

        d = new Element
          key: "c"
          size: testNestedSizeLayout
          new Element size: 30, key: "d"

    ->
      assert.eq d.currentSize, point(30), "d.currentSize"
      assert.eq c.currentSize, point(25), "c.currentSize"
      assert.eq b.currentSize, point(30), "b.currentSize"
      assert.eq a.currentSize, point 100, 30

  stateEpochTest "regression 2b - more than one nesting of an element which is both parent and child relative breaks", ->
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

    a = new Element
      key: "a"
      size:
        hch:1
        w: 100

      b = new Element
        key: "b"
        size: testNestedSizeLayout

        c = new Element
          key: "c"
          size: testNestedSizeLayout
          new Element size: 25, key: "d"

        d = new Element
          key: "c"
          size: testNestedSizeLayout
          new Element size: 30, key: "d"

    ->
      assert.eq d.currentSize, point(0, 30), "d.currentSize"
      assert.eq c.currentSize, point(0, 25), "c.currentSize"
      assert.eq b.currentSize, point(0), "b.currentSize"
      assert.eq a.currentSize, point 100, 0

  stateEpochTest "regression 3", ->
    gp = new Element
      size: w:150, hch: 1
      p1 = new Element
        size: cs: 1, max: ww: 1
        c1 = new Element size: 50

      p2 = new Element
        size: cs: 1, max: ww: 1
        c2 = new Element size: 200
    ->
      assert.eq gp.currentSize, point 150, 200
      assert.eq p1.currentSize, point 50
      assert.eq p2.currentSize, point 150, 200

