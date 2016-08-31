Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'

{point, matrix, Point} = Atomic
{Layout} = Engine
{point0} = Point
{log, inspect, min, max, deepMap, isFunction, formattedInspect} = Foundation
{PointLayout} = Layout

ps = point 100, 200
cs = point 30, 40

testLayout = (shouldBeX, shouldBeY, params) ->
  shouldBe = point shouldBeX, shouldBeY
  # preprocessedParams = deepMap params, (v) -> if isFunction v then v.toString() else v
  test "#{formattedInspect params}", ->
    pointLayout = new PointLayout params
    assert.eq shouldBe, pointLayout.layout(ps, cs), """
      testLayout:
        layout:         #{formattedInspect pointLayout.initializer}
        ps:             #{inspect ps}
        cs:             #{inspect cs}
        outputWas:      #{inspect pointLayout.layout(ps, cs)}
        outputShouldBe: #{inspect shouldBe}
      """
    assert.eq shouldBe.x, pointLayout.layoutX(ps, cs), "testing X of PointLayout #{formattedInspect pointLayout.initializer}"
    assert.eq shouldBe.y, pointLayout.layoutY(ps, cs), "testing X of PointLayout #{formattedInspect pointLayout.initializer}"

ps2 = point 10, 20

suite "Art.Engine.Layout.PointLayout.constructor", ->
  test "new PointLayout",             -> assert.equal new PointLayout().toString(),             'PointLayout(0)'
  test "new PointLayout ps:1",        -> assert.equal new PointLayout(ps:1).toString(),         'PointLayout(ps: 1)'
  test "new PointLayout point0",      -> assert.equal new PointLayout(point0).toString(),       'PointLayout(0)'
  test "new PointLayout point(1,2)",  -> assert.equal new PointLayout(point 1, 2).toString(),   'PointLayout(point(1, 2))'
  test "new PointLayout x: -> 1",     ->
    f = -> 1
    assert.match new PointLayout(x: f).toString(), /PointLayout\(x\: (f|function)\(\)\)/

suite "Art.Engine.Layout.PointLayout.layout.basic", ->
  testLayout   0,   0,    null
  testLayout   0,   0,    {}
  testLayout 123, 123,    123
  testLayout 123, 456,    point(123, 456)

suite "Art.Engine.Layout.PointLayout.layout.strings", ->
  testLayout   0,   0,    'topLeft'
  testLayout  50, 100,    'centerCenter'
  testLayout 100, 200,    'bottomRight'

suite "Art.Engine.Layout.PointLayout.layout.functions", ->
  testLayout 100, 200,    (ps) -> ps
  testLayout 130, 240,    (ps, cs) -> ps.add cs

  testLayout 100,   0,    x: (ps) -> ps.x
  testLayout   0, 200,    y: (ps) -> ps.y

  testLayout 100, 200,
                          x: (ps) -> ps.x
                          y: (ps) -> ps.y

  testLayout 123, 200,    x: 123, y: (ps) -> ps.y

suite "Art.Engine.Layout.PointLayout.layout.illegal", ->
  test "x: point0 - illegal", ->
    assert.throws -> new PointLayout x: point0

  test "{invalid: 1} throws error", ->
    assert.throws -> pl = new PointLayout invalid: 1

suite "Art.Engine.Layout.PointLayout.layout.options", ->
  testLayout   1,   1,    plus: 1
  testLayout 100, 200,    ps: 1
  testLayout  30,  40,    cs: 1
  testLayout   1,   0,    x: 1
  testLayout   0,   1,    y: 1
  testLayout 100,   0,    xw: 1
  testLayout   0, 200,    yh: 1

  testLayout 200,   0,    xh: 1
  testLayout   0, 100,    yw: 1

  testLayout  50,   0,    xw: .5
  testLayout   0, 100,    yh: .5

  testLayout  30,   0,    xcw: 1
  testLayout   0,  40,    ych: 1
  testLayout(
    2 * (ps.x + cs.x + 1)
    2 * (ps.y + cs.y + 1)
    x:1, y:1, xpw:1, yph:1, xcw:1, ych:1, ps:1, cs:1, plus:1
  )

  testLayout  ps.x * 1.0, ps.y * 0.5,  ps:  "centerRight"
  testLayout  cs.x * 1.0, cs.y * 0.5,  cs:  "centerRight"
  testLayout         1.0,        0.5,  pts: "centerRight"

  testLayout  ps.x * 0.6, ps.y * 0.7,  ps:  point .6, .7
  testLayout  cs.x * 0.6, cs.y * 0.7,  cs:  point .6, .7
  testLayout         0.6,        0.7,  pts: point .6, .7

suite "Art.Engine.Layout.PointLayout.max", ->
  testLayout  10, 100,    w: 10,  h:100,  max: w: 50
  testLayout  50,  10,    w: 100, h:10,   max: w: 50

  test "max does not effect relativity", ->
    pl1 = new PointLayout w: 100, h:10, max: ww: 1
    pl2 = new PointLayout ww: 1,  h:10, max: ww: 1
    assert.eq false, pl1.getParentRelative()
    assert.eq true,  pl2.getParentRelative()

suite "Art.Engine.Layout.PointLayout.Dependencies", ->
  test "new PointLayout - not relative", ->
    pl = new PointLayout
    assert.eq pl.parentRelative, false
    assert.eq pl.childrenRelative, false

  test "new PointLayout -> 1 - not relative", ->
    pl = new PointLayout -> 1
    assert.eq pl.parentRelative, false
    assert.eq pl.childrenRelative, false

  test "new PointLayout (ps, cs) -> 1 - not relative", ->
    pl = new PointLayout (ps, cs) -> 1
    assert.eq pl.parentRelative, false
    assert.eq pl.childrenRelative, false

  test "new PointLayout (ps, cs) -> ps - only parent relative", ->
    log "a"
    pl = new PointLayout (ps, cs) -> ps
    log "b"
    # assert.eq pl.parentRelative, true
    assert.eq pl.childrenRelative, false

  test "new PointLayout (ps, cs) -> cs - only children relative", ->
    pl = new PointLayout (ps, cs) -> cs
    assert.eq pl.parentRelative, false
    assert.eq pl.childrenRelative, true

  test "new PointLayout (ps, cs) -> ps.add cs - both relative", ->
    pl = new PointLayout (ps, cs) -> ps.add cs
    assert.eq pl.parentRelative, true
    assert.eq pl.childrenRelative, true

  test "new PointLayout x: (ps) -> ps.x - parent width relative", ->
    log "!!!!!!!!!!!!"
    pl = new PointLayout x: (ps) -> ps.x
    log pointLayout: pl, layoutX:pl.layoutX(point 100), layoutXLength: pl.layoutX.length, layoutX: pl.layoutX.toString()

    assert.eq pl.parentRelative,      true,  "parentRelative"
    assert.eq pl.childrenRelative,    false, "childrenRelative"
    assert.eq pl.xRelativeToParentW,  true,  "xRelativeToParentW"
    assert.eq pl.xRelativeToParentH,  false, "xRelativeToParentH" # this one
    assert.eq pl.yRelativeToParentW,  false, "yRelativeToParentW"
    assert.eq pl.yRelativeToParentH,  false, "yRelativeToParentH"

  test "regression foo", ->
    pl1 = new PointLayout w:220, hch:1
    pl2 = new PointLayout wcw:1, hh:1
    assert.eq pl1.childrenRelative, true
    assert.eq pl2.parentRelative, true

  test "regressionA with min", ->
    pl = new PointLayout
      hch: 1
      w: (ps, cs) -> min ps.w, cs.w
    assert.eq pl.parentRelative,        true,   "parentRelative"
    assert.eq pl.childrenRelative,      true,   "childrenRelative"
    assert.eq pl.xRelativeToParentW,    true,   "xRelativeToParentW"
    assert.eq pl.xRelativeToParentH,    false,  "xRelativeToParentH"
    assert.eq pl.yRelativeToParentW,    false,  "yRelativeToParentW"
    assert.eq pl.yRelativeToParentH,    false,  "yRelativeToParentH"

    assert.eq pl.xRelativeToChildrenW,  true,   "xRelativeToChildrenW"
    assert.eq pl.xRelativeToChildrenH,  false,  "xRelativeToChildrenH"
    assert.eq pl.yRelativeToChildrenW,  false,  "yRelativeToChildrenW"
    assert.eq pl.yRelativeToChildrenH,  true,   "yRelativeToChildrenH"

  test "regressionB with max", ->
    pl = new PointLayout
      hch: 1
      w: (ps, cs) -> max ps.w, cs.w
    assert.eq pl.parentRelative, true
    assert.eq pl.childrenRelative, true
    assert.eq pl.xRelativeToParentW, true
    assert.eq pl.xRelativeToParentH, false
    assert.eq pl.yRelativeToParentW, false
    assert.eq pl.yRelativeToParentH, false

    assert.eq pl.xRelativeToChildrenW, true
    assert.eq pl.xRelativeToChildrenH, false
    assert.eq pl.yRelativeToChildrenW, false
    assert.eq pl.yRelativeToChildrenH, true

  test "regression with inf parent size", ->
    pl = new PointLayout ww:1, hch:1
    ps = point 100, 1.0000000000000002e+100
    cs = point 100, 30
    assert.eq 100, pl.layoutX ps, cs
    assert.eq 30, pl.layoutY ps, cs

  test "new PointLayout x:1, y:2 - not relative", ->
    pl = new PointLayout x:1, y:2
    assert.eq pl.parentRelative, false
    assert.eq pl.childrenRelative, false

  test "new PointLayout ps:1 - parent relative", ->
    pl = new PointLayout ps:1
    assert.eq pl.parentRelative, true
    assert.eq pl.childrenRelative, false

  test "new PointLayout cs:1 - parent relative", ->
    pl = new PointLayout cs:1
    assert.eq pl.parentRelative, false
    assert.eq pl.childrenRelative, true

  test "interpolate 0", ->
    pl1 = new PointLayout 100
    pl2 = new PointLayout 200
    ipl = pl1.interpolate pl2, 0
    assert.equal ipl, pl1

  test "interpolate 1", ->
    pl1 = new PointLayout 100
    pl2 = new PointLayout 200
    ipl = pl1.interpolate pl2, 1
    assert.equal ipl, pl2

  test "interpolate .5", ->
    pl1 = new PointLayout 100
    pl2 = new PointLayout 200
    ipl = pl1.interpolate pl2, .5
    assert.eq ipl.layoutX(), 150
    assert.eq ipl.layoutY(), 150

  test "detecting child relativity when using 'min' function", ->
    pl1 = new PointLayout h: (ps, cs) -> min cs.y, ps.y
    pl2 = new PointLayout h: (ps, cs) -> min cs.y, max ps.y, 100
    assert.eq true, pl1.getChildrenRelative()
    assert.eq true, pl2.getChildrenRelative()

suite "Art.Engine.Layout.PointLayout.failed-detection warnings", ->
  test "should warn x-funtion not detected to be parent relative", ->
    new PointLayout x: (ps) -> 0

  test "should warn y-funtion not detected to be parent relative", ->
    new PointLayout y: (ps) -> 0

  test "should warn x-funtion not detected to be children relative", ->
    new PointLayout x: (ps, cs) -> 0

  test "should warn y-funtion not detected to be children relative", ->
    new PointLayout y: (ps, cs) -> 0

suite "Art.Engine.Layout.PointLayout.defaults", ->
  test "relativity should pass through for defaults", ->
    pl = new PointLayout {}, def = new PointLayout hh: 1, wcw: 1
    for k in [
        "xRelativeToParentW"
        "xRelativeToParentH"
        "xRelativeToChildrenW"
        "xRelativeToChildrenH"
        "yRelativeToParentW"
        "yRelativeToParentH"
        "yRelativeToChildrenW"
        "yRelativeToChildrenH"
      ]
      assert.eq def[k], pl[k], k

  test "regression", ->
    l = new PointLayout (w:30, h: (ps) -> max 60, ps.y) #, new PointLayout ps: 1
    log l.layout point(100)
