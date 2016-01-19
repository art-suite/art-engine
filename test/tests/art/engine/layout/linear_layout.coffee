define [
  'art-foundation'
  'art-atomic'
  'art-engine'
], (Foundation, Atomic, {Layout:{LinearLayout}}) ->

  {point, matrix, Point} = Atomic
  {point0} = Point
  {log, inspect} = Foundation

  suite "Art.Engine.Layout.LinearLayout", ->
    test "constructor", ->
      assert.equal new LinearLayout().toString(true), '{[l: 0], [ss: 1]}'

    test "oldOptions doesn't replace newOptions max", ->
      l = new LinearLayout {l:0, ss:1, max: s:200}, {hch:1, ww:1}
      assert.equal l.toString(), '{l: 0, ss: 1, max: {s: 200}}'

    test "oldOptions doesn't replace newOptions min", ->
      l = new LinearLayout {l:0, ss:1, min: s:200}, {hch:1, ww:1}
      assert.equal l.toString(), '{l: 0, ss: 1, min: {s: 200}}'

    test "oldOptions.max is merged with newOptions.max", ->
      l = new LinearLayout {l:0, ss:1, max: s:200}, {hch:1, ww:1, max: l:-100, s:100}
      assert.equal l.toString(), '{l: 0, ss: 1, max: {l: -100, s: 200}}'

    test "forceHasAllLayout", ->
      assert.equal new LinearLayout(null, null, true).toString(true), '{l: 0, ss: 1}'

    test "layout constants", ->
      l = new LinearLayout x: 10, y: 10, w: 100, h: 100
      assert.eq l.toString(true), '{l: 10, s: 100}'

    test "layout x only", ->
      l = new LinearLayout x: 10
      assert.eq l.toString(true), '{x: 10, [y: 0], [ss: 1]}'

    test "layout location only", ->
      l = new LinearLayout x: 10, y: 10
      assert.eq l.transformLocation(point 300), point 10, 10
      assert.eq l.toString(true), '{l: 10, [ss: 1]}'

    test "layout size only", ->
      l = new LinearLayout w: 10, h: 10
      assert.eq l.toString(true), '{[l: 0], s: 10}'

    test "layout using l & s (a)", ->
      l1 = new LinearLayout x:100, ls:1
      l2 = new LinearLayout x:100, xw:1, yh:1
      assert.eq l1, l2

    test "layout using l & s (b)", ->
      l1 = new LinearLayout x:5, y:8, ls:.5, yh:.7, s:point(10, 20), ss:1
      l2 = new LinearLayout x:5, y:8, xw:.5, yh:.7, w:10, h:20, ww:1, hh:1
      assert.eq l1, l2

    test "layout max location and not size", ->
      l = new LinearLayout xw: 1, yh: 1, s:123, max: x:400
      assert.eq l.toString(true), '{ls: 1, s: 123, max: {x: 400}}'
      assert.eq l.transformSize(point 300), point 123
      assert.eq l.transformLocation(point 300), point 300
      assert.eq l.transformLocation(point 400), point 400
      assert.eq l.transformLocation(point 500), point 400, 500

    test "layout max size and not location", ->
      l = new LinearLayout x:100, y: 200, ss:1, max: w:400, h:300
      assert.eq l.toString(true), '{x: 100, y: 200, ss: 1, max: {w: 400, h: 300}}'
      assert.eq l.transformLocation(point 300), point 100, 200

      assert.eq l.transformSize(point 300), point 300, 300
      assert.eq l.transformSize(point 400), point 400, 300
      assert.eq l.transformSize(point 500), point 400, 300

    test "layout min", ->
      l = new LinearLayout xw: 1, yh: 1, min: x:400
      assert.eq l.toString(true), '{ls: 1, [ss: 1], min: {x: 400}}'
      assert.eq l.transformLocation(point 300), point 400, 300
      assert.eq l.transformLocation(point 400), point 400, 400
      assert.eq l.transformLocation(point 500), point 500, 500

    test "layout max min not overlapped", ->
      l = new LinearLayout xw:.5, yh:.2, ww:1, h:50, max: {w:800}, min: {y:100}
      assert.eq l.transformLocation(point 1000, 400), point 500, 100
      assert.eq l.transformSize(point 1000, 400), point 800, 50
      assert.eq l.transformSize(point 100, 400), point 100, 50

    test "layout constant location, variable size", ->
      l = new LinearLayout
        x:  100, y: 100
        ww: 1,   w:-100
        hh: 1,   h:-100
      assert.eq l.toString(true), "{l: 100, s: -100, ss: 1}"

    test "layout variable location, constant size", ->
      l = new LinearLayout
        xw: 1, x: -10
        yh: 1, y: -10
        w: 10, h:  10
      assert.eq l.toString(true), "{l: -10, ls: 1, s: 10}"

    test "layout inversly variable size - useful if rotated 90deg", ->
      # imagine
      #   axis = point(1, 0) # upper-right corner
      #   angle = PI/4 # or is it -PI/4 ???
      l = new LinearLayout x:0, y:0, wh: 1, hw: 1
      assert.eq l.toString(true), '{l: 0, ssh: 1}'

    test "layout partially only updates partially", ->
      l = new LinearLayout x:0, y:0, ww: .5, hh: .5
      assert.eq l.toString(true), '{l: 0, ss: 0.5}'

      l.layout xw: .25, yh: .25
      assert.eq l.toString(true), '{ls: 0.25, ss: 0.5}'

      l.layout yh: .5
      assert.eq l.toString(true), '{xw: 0.25, yh: 0.5, ss: 0.5}'

    test "new layout based on old layout only updates partially", ->
      l = new LinearLayout x:0, y:0, ww: .5, hh: .5
      l2 = new LinearLayout yh: 1, l

      assert.eq l2.toString(true), '{x: 0, yh: 1, ss: 0.5}'

    test "new layout based on previous options only updates partially", ->
      l2 = new LinearLayout yh: 1, {x:0, y:0, ww: .5, hh: .5}

      assert.eq l2.toString(true), '{x: 0, yh: 1, ss: 0.5}'

    suite "children relative", ->
      test "width", ->
        l2 = new LinearLayout wcw: 1
        assert.eq l2.toString(true), '{[l: 0], wcw: 1, [hh: 1]}'
        assert.eq 3, l2.transformSizeX point(1, 2), point(3, 4)

      test "height", ->
        l2 = new LinearLayout hch: 1
        assert.eq l2.toString(true), '{[l: 0], [ww: 1], hch: 1}'
        assert.eq 4, l2.transformSizeY point(1, 2), point(3, 4)

      test "both", ->
        l2 = new LinearLayout wcw: 1, wch:2, hch: 3, hcw: 4
        assert.eq l2.toString(true), '{[l: 0], wcw: 1, wch: 2, hcw: 4, hch: 3}'
        assert.eq 11, l2.transformSizeX point(1, 2), point(3, 4)
        assert.eq 24, l2.transformSizeY point(1, 2), point(3, 4)

    test "children - min and max", ->
      l = new LinearLayout
        w: 10000
        h: 60000
        max: ss:1, s:-50
        min: w: 400, h: 250

      assert.eq 590, l.transformSizeX point(640, 514), point0
      assert.eq 514-50, l.transformSizeY point(640, 514), point0

    test "sizeChildRelative", ->
      l1 = new LinearLayout s:50
      l2 = new LinearLayout scs: 1
      assert.eq false, l1.sizeParentRelative
      assert.eq false, l2.sizeParentRelative
      assert.eq false, l1.sizeChildRelative
      assert.eq true,  l2.sizeChildRelative

    test "sizeParentRelative", ->
      l1 = new LinearLayout s:50
      l2 = new LinearLayout ss: 1
      assert.eq false, l1.sizeParentRelative
      assert.eq true,  l2.sizeParentRelative
      assert.eq false, l1.sizeChildRelative
      assert.eq false, l2.sizeChildRelative

    test "sizeLayoutCircular nothing relative", ->
      parent = new LinearLayout s:50
      child  = new LinearLayout s:20
      assert.eq false, child.sizeLayoutCircular parent

    test "sizeLayoutCircular parent not relative", ->
      parent = new LinearLayout s:50
      child  = new LinearLayout ss:1
      assert.eq false, child.sizeLayoutCircular parent

    test "sizeLayoutCircular child not relative", ->
      parent = new LinearLayout scs:1
      child  = new LinearLayout s:20
      assert.eq false, child.sizeLayoutCircular parent

    test "sizeLayoutCircular both fully relative", ->
      parent = new LinearLayout scs:1
      child  = new LinearLayout ss:1
      assert.eq true, child.sizeLayoutCircular parent

    test "sizeLayoutCircular both relative to others, but not each other", ->
      parent = new LinearLayout ss:1
      child  = new LinearLayout scs:1
      assert.eq false, child.sizeLayoutCircular parent

    test "sizeLayoutCircular wcw-hh non-circular", ->
      parent = new LinearLayout wcw:1, h: 50
      child  = new LinearLayout w:20, hh: 1
      assert.eq false, child.sizeLayoutCircular parent

    test "sizeLayoutCircular hh-hch circular", ->
      parent = new LinearLayout w:1, hch: 1
      child  = new LinearLayout w:1, hh: 1
      assert.eq true, child.sizeLayoutCircular parent

    test "sizeLayoutCircular ww-wcw circular", ->
      parent = new LinearLayout h:1, wcw: 1
      child  = new LinearLayout h:1, ww: 1
      assert.eq true, child.sizeLayoutCircular parent

    test "sizeLayoutCircular hw-wch circular", ->
      parent = new LinearLayout h:  1, wch: 1
      child  = new LinearLayout hw: 1, w:   1
      assert.eq true, child.sizeLayoutCircular parent

    test "sizeLayoutCircular hcw-wh circular", ->
      parent = new LinearLayout hcw: 1, w:  1
      child  = new LinearLayout h:   1, wh: 1
      assert.eq true, child.sizeLayoutCircular parent

    test "sizeLayoutCircular hcw-ww-wch-ww circular", ->
      parent = new LinearLayout hcw: 1, wch:  1
      child  = new LinearLayout hh:  1, ww: 1
      assert.eq true, child.sizeLayoutCircular parent

    test "sizeLayoutCircular hch-hw-wcw-wh circular", ->
      parent = new LinearLayout hch: 1, wcw:  1
      child  = new LinearLayout hw:  1, wh: 1
      assert.eq true, child.sizeLayoutCircular parent

    test "sizeLayoutCircular hcw-ww-wch non-circular", ->
      parent = new LinearLayout hcw: 1, wch:  1
      child  = new LinearLayout h:   1, ww: 1
      assert.eq false, child.sizeLayoutCircular parent

    test "areaLayoutCircular scs-ls-s circular", ->
      parent = new LinearLayout scs: 1
      child = new LinearLayout ls: 1, s:25
      assert.eq true, child.areaLayoutCircular parent

    test "areaLayoutCircular wcw-w, hh-h non-circular", ->
      parent = new LinearLayout wcw: 1, h:100
      child = new LinearLayout w: 200, hh:1
      assert.eq false, child.areaLayoutCircular parent

    test "interpolate {x:10}, {x:20}, .25", ->
      a = new LinearLayout x:10
      b = new LinearLayout x:20
      assert.eq a.interpolate(b, .25).toString(), "({x: 10} * 0.75 + {x: 20} * 0.25)"

    test "interpolate {x:10}, {x:20}, 0", ->
      a = new LinearLayout x:10
      b = new LinearLayout x:20
      assert.eq a.interpolate(b, 0).toString(), "{x: 10}"

    test "interpolate {x:10}, {x:20}, 1", ->
      a = new LinearLayout x:10
      b = new LinearLayout x:20
      assert.eq a.interpolate(b, 1).toString(), "{x: 20}"

    test "layout ls:0", ->
      a = new LinearLayout ls:0
      assert.eq a.toString(true), "{l: 0, [ss: 1]}"
      assert.eq true, a.hasXLayout
      assert.eq true, a.hasYLayout

    test "layout x:0", ->
      a = new LinearLayout x:0
      assert.eq a.toString(true), "{x: 0, [y: 0], [ss: 1]}"
      assert.eq true, a.hasXLayout
      assert.eq false, a.hasYLayout

    test "layout s:0", ->
      a = new LinearLayout s:0
      assert.eq a.toString(true), "{[l: 0], s: 0}"
      assert.eq true, a.hasWLayout
      assert.eq true, a.hasHLayout

    test "layout s:point 0, 1", ->
      a = new LinearLayout s: point 0, 1
      assert.eq a.toString(true), "{[l: 0], w: 0, h: 1}"
      assert.eq false, a.hasXLayout
      assert.eq false, a.hasYLayout
      assert.eq true, a.hasWLayout
      assert.eq true, a.hasHLayout

    test "layout ls:1", ->
      b = new LinearLayout ls:1
      assert.eq b.toString(true), "{ls: 1, [ss: 1]}"
      assert.eq true, b.hasXLayout
      assert.eq true, b.hasYLayout

    test "layout interpolate with max", ->
      l1 = new LinearLayout l:100, ss:1
      l2 = new LinearLayout l:200, ss:2, max: s:40
      l3 = l1.interpolate l2, .5
      assert.eq l1.toString(true), '{l: 100, ss: 1}'
      assert.eq l2.toString(true), '{l: 200, ss: 2, max: {s: 40}}'
      assert.eq l3.toString(true), '({l: 100, ss: 1} * 0.5 + {l: 200, ss: 2, max: {s: 40}} * 0.5)'
      assert.eq l3.transformSize(point 10), point 15
      assert.eq l3.transformSize(point 20), point 30
      assert.eq l3.transformSize(point 30), point 35
      assert.eq l3.transformLocation(point 10), point 150

    test "layout interpolate without size", ->
      l1 = new LinearLayout l:100, s:200
      l2 = new LinearLayout l:200
      l3 = l1.interpolate l2, .5
      assert.eq l3.toString(true), '({l: 100, s: 200} * 0.5 + {l: 200, [ss: 1]} * 0.5)'
      assert.eq l3.transformSize(point 1000), point 200
      assert.eq l3.transformLocation(point 1000), point 150

      l2 = new LinearLayout l:200, ss:1
      l3 = l1.interpolate l2, .5
      assert.eq l3.toString(true), '({l: 100, s: 200} * 0.5 + {l: 200, ss: 1} * 0.5)'
      assert.eq l3.transformSize(point 1000), point 600
      assert.eq l3.transformLocation(point 1000), point 150
