define [

  'art.foundation'
  'art.atomic'
  'art.engine'
], (Foundation, Atomic, {Layout}) ->

  {point, matrix, Point} = Atomic
  {point0} = Point
  {log, inspect, min, max} = Foundation
  {PointLayout} = Layout

  ps = point 100, 200
  cs = point 30, 40

  ps2 = point 10, 20
  suite "Art.Engine.Layout.PointLayout", ->
    suite "constructor", ->
      test "new PointLayout",         -> assert.equal new PointLayout().toString(),         'PointLayout(0)'
      test "new PointLayout ps:1",    -> assert.equal new PointLayout(ps:1).toString(),     'PointLayout(ps: 1)'
      test "new PointLayout point0",  -> assert.equal new PointLayout(point0).toString(),   'PointLayout(point(0, 0))'
      test "new PointLayout x: -> 1", -> assert.equal new PointLayout(x: -> 1).toString(),  'PointLayout(x: function())'

    suite "layout", ->
      test "default", ->
        pl = new PointLayout
        assert.eq 0, pl.layoutX ps, cs
        assert.eq 0, pl.layoutY ps, cs
        assert.eq point0, pl.layout ps, cs

      test "123", ->
        pl = new PointLayout 123
        assert.eq 123, pl.layoutX ps, cs
        assert.eq 123, pl.layoutY ps, cs
        assert.eq point(123), pl.layout ps, cs

      test "point 123, 456", ->
        pl = new PointLayout p = point 123, 456
        assert.eq 123, pl.layoutX ps, cs
        assert.eq 456, pl.layoutY ps, cs
        assert.equal p, pl.layout ps, cs

      test "(ps) -> ps", ->
        pl = new PointLayout (ps) -> ps
        assert.eq 100, pl.layoutX ps, cs
        assert.eq 200, pl.layoutY ps, cs
        assert.equal ps, pl.layout ps, cs

      test "(ps, cs) -> ps.add cs", ->
        pl = new PointLayout (ps, cs) -> ps.add cs
        assert.eq 130, pl.layoutX ps, cs
        assert.eq 240, pl.layoutY ps, cs
        assert.eq (ps.add cs), pl.layout ps, cs

      test "x: (ps) -> ps.x", ->
        pl = new PointLayout x: (ps) -> ps.x
        assert.eq 100, pl.layoutX ps, cs
        assert.eq 0, pl.layoutY ps, cs

      test "y: (ps) -> ps.y", ->
        pl = new PointLayout y: (ps) -> ps.y
        assert.eq 0, pl.layoutX ps, cs
        assert.eq 200, pl.layoutY ps, cs

      test "x: ->, y: ->", ->
        pl = new PointLayout
          x: (ps) -> ps.x
          y: (ps) -> ps.y
        assert.eq 100, pl.layoutX ps, cs
        assert.eq 200, pl.layoutY ps, cs
        assert.notEqual ps, pl.layout ps, cs

      test "x:123, y: (ps) -> ps.y", ->
        pl = new PointLayout x: 123, y: (ps) -> ps.y

        assert.eq 123, pl.layoutX ps, cs
        assert.eq 200, pl.layoutY ps, cs

      test "plus: 1", ->
        pl = new PointLayout plus: 1
        assert.eq 1, pl.layoutX ps, cs
        assert.eq 1, pl.layoutY ps, cs

      test "x: point0 - illegal", ->
        assert.throws -> new PointLayout x: point0

      test "ps: 1", ->
        pl = new PointLayout ps: 1
        assert.eq 100, pl.layoutX ps, cs
        assert.eq 200, pl.layoutY ps, cs
        assert.notEqual ps, pl.layout ps, cs
        assert.eq ps, pl.layout ps, cs

      test "cs: 1", ->
        pl = new PointLayout cs: 1
        assert.eq 30, pl.layoutX ps, cs
        assert.eq 40, pl.layoutY ps, cs
        assert.notEqual cs, pl.layout ps, cs
        assert.eq cs, pl.layout ps, cs

      test "x: 1", ->
        pl = new PointLayout x: 1
        assert.eq 1, pl.layoutX ps, cs
        assert.eq 0, pl.layoutY ps, cs

      test "y: 1", ->
        pl = new PointLayout y: 1
        assert.eq 0, pl.layoutX ps, cs
        assert.eq 1, pl.layoutY ps, cs

      test "xpw: 1", ->
        pl = new PointLayout xpw: 1
        assert.eq 100, pl.layoutX ps, cs
        assert.eq 0, pl.layoutY ps, cs

      test "yph: 1", ->
        pl = new PointLayout yph: 1
        assert.eq 0, pl.layoutX ps, cs
        assert.eq 200, pl.layoutY ps, cs

      test "xpw: .5", ->
        pl = new PointLayout xpw: .5
        assert.eq 50, pl.layoutX ps, cs
        assert.eq 0, pl.layoutY ps, cs

      test "yph: .5", ->
        pl = new PointLayout yph: .5
        assert.eq 0, pl.layoutX ps, cs
        assert.eq 100, pl.layoutY ps, cs

      test "xcw: 1", ->
        pl = new PointLayout xcw: 1
        assert.eq 30, pl.layoutX ps, cs
        assert.eq 0, pl.layoutY ps, cs

      test "ych: 1", ->
        pl = new PointLayout ych: 1
        assert.eq 0, pl.layoutX ps, cs
        assert.eq 40, pl.layoutY ps, cs

      test "x:1, y:1, xpw:1, yph:1, xcw:1, ych:1, ps:1, cs:1, plus:1", ->
        pl = new PointLayout x:1, y:1, xpw:1, yph:1, xcw:1, ych:1, ps:1, cs:1, plus:1
        assert.eq 2 * (ps.x + cs.x + 1), pl.layoutX ps, cs
        assert.eq 2 * (ps.y + cs.y + 1), pl.layoutY ps, cs

      test "{invalid: 1} throws error", ->
        assert.throws -> pl = new PointLayout invalid: 1

    suite "max", ->
      test "basic A", ->
        pl = new PointLayout w: 10, h:100, max: w: 50
        assert.eq 10,  pl.layoutX ps
        assert.eq 100, pl.layoutY ps

      test "basic B", ->
        pl = new PointLayout w: 100, h:10, max: w: 50
        assert.eq 50,  pl.layoutX ps
        assert.eq 10, pl.layoutY ps

      test "max does now effect relativity", ->
        pl1 = new PointLayout w: 100, h:10, max: ww: 1
        pl2 = new PointLayout ww: 1,  h:10, max: ww: 1
        assert.eq false, pl1.getParentRelative()
        assert.eq true,  pl2.getParentRelative()

    suite "Dependencies", ->
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
        pl = new PointLayout x: (ps) -> ps.x
        assert.eq pl.parentRelative, true
        assert.eq pl.childrenRelative, false
        assert.eq pl.xRelativeToParentW, true
        assert.eq pl.xRelativeToParentH, false # this one
        assert.eq pl.yRelativeToParentW, false
        assert.eq pl.yRelativeToParentH, false

      test "regressionA with min", ->
        pl = new PointLayout
          hch: 1
          w: (ps, cs) -> min ps.w, cs.w
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

      suite "failed-detection warnings", ->
        test "should warn x-funtion not detected to be parent relative", ->
          new PointLayout x: (ps) -> 0

        test "should warn y-funtion not detected to be parent relative", ->
          new PointLayout y: (ps) -> 0

        test "should warn x-funtion not detected to be children relative", ->
          new PointLayout x: (ps, cs) -> 0

        test "should warn y-funtion not detected to be children relative", ->
          new PointLayout y: (ps, cs) -> 0
