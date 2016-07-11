define [
  'art-atomic'
  'art-foundation'
  './point_layout_base'
], (Atomic, Foundation, PointLayoutBase) ->

  {point, Point} = Atomic
  {point0} = Point
  {BaseObject, log, inspect, inspectLean, isFunction, isNumber, isString, isPlainObject, min, max} = Foundation

  # a singleton to help make initializing from component-options fast
  class Components

    @setupPointLayout: (linearLayout, options, previousLayout) ->
      maxLayout = if options.max then new PointLayout options.max
      @_reset()
      for k, v of options
        applyFunction = applyComponentsFunctions[k]
        throw new Error "invalid PointLayout component: #{inspect k} in #{inspect options}" unless applyFunction
        applyFunction v, linearLayout

      linearLayout.layoutX = if linearLayout._hasXLayout then @_buildXLayoutFromComponents(maxLayout) else if previousLayout?._hasXLayout then linearLayout._hasXLayout = true; previousLayout.layoutX else -> 0
      linearLayout.layoutY = if linearLayout._hasYLayout then @_buildYLayoutFromComponents(maxLayout) else if previousLayout?._hasYLayout then linearLayout._hasYLayout = true; previousLayout.layoutY else -> 0

      linearLayout._detectXRelativity() if @needToDetectXRelativity
      linearLayout._detectYRelativity() if @needToDetectYRelativity

    ###################
    # private
    ###################
    @_buildXLayoutFromComponents: (maxLayout) ->
      # copy all members we use into this closure
      # do not access anything on '@' inside the functions created velow
      {x, xpw, xph, xcw, layoutX} = @

      layoutX ||= if xcw == 0
            (ps)     -> x + xpw * ps.x + xph * ps.y
      else  (ps, cs) -> x + xpw * ps.x + xph * ps.y + xcw * cs.x

      if maxLayout?.getHasXLayout()
        (ps, cs) -> min maxLayout.layoutX(ps), layoutX ps, cs
      else
        layoutX

    @_buildYLayoutFromComponents: (maxLayout) ->
      {y, yph, ypw, ych, layoutY} = @   # copy all members we use into this closure

      layoutY ||= if ych == 0
            (ps)     -> y + yph * ps.y + ypw * ps.x
      else  (ps, cs) -> y + yph * ps.y + ypw * ps.x + ych * cs.y

      if maxLayout?.getHasYLayout()
        (ps, cs) -> min maxLayout.layoutY(ps), layoutY ps, cs
      else
        layoutY



    @_reset: ->
      @needToDetectXRelativity = false
      @needToDetectYRelativity = false
      @layoutX = null
      @layoutY = null
      @x   =
      @xpw =
      @xph =
      @xcw =
      @y   =
      @yph =
      @ypw =
      @ych = 0.0

    @_reset()

    preprocessValue = (value, pointLayout) ->
      value ||= 0
      throw new Error "Each PointLayout component must be a number. Not #{inspect value} from #{pointLayout}" unless isNumber value
      value

    @_applyComponentsFunctions: applyComponentsFunctions =

      max: (value, pointLayout) ->
        # noop - this exists to validate it is a legal option, but it is handled elsewhere

      # all layout is in length-units of "pts" (points).
      # Points == Pixels for non-retina screens (pixelsPerPoint == 1)
      # provide numbers or 2d Points (not to be confused with pts, the length unit) to add to your layout.
      pts: pts = (value, pointLayout) ->
        value = preprocessValue value, pointLayout
        pointLayout._hasXLayout =
        pointLayout._hasYLayout = true
        Components.x += value
        Components.y += value

      x: x = (value, pointLayout) ->
        pointLayout._hasXLayout = true
        if isFunction value
          Components.layoutX = value
          Components.needToDetectXRelativity = true
        else
          value = preprocessValue value, pointLayout
          Components.x += value

      y: y = (value, pointLayout) ->
        pointLayout._hasYLayout = true
        if isFunction value
          Components.layoutY = value
          Components.needToDetectYRelativity = true
        else
          value = preprocessValue value, pointLayout
          Components.y += value

      # parent-relative components
      ps: (value, pointLayout) ->
        value = preprocessValue value, pointLayout
        pointLayout._hasXLayout =
        pointLayout._hasYLayout =
        pointLayout._xRelativeToParentW =
        pointLayout._yRelativeToParentH = true
        Components.xpw += value
        Components.yph += value

      xpw: xpw = (value, pointLayout) ->
        value = preprocessValue value, pointLayout
        pointLayout._hasXLayout =
        pointLayout._xRelativeToParentW = true
        Components.xpw += value

      yph: yph = (value, pointLayout) ->
        value = preprocessValue value, pointLayout
        pointLayout._hasYLayout =
        pointLayout._yRelativeToParentH = true
        Components.yph += value

      xph: xph = (value, pointLayout) ->
        value = preprocessValue value, pointLayout
        pointLayout._hasXLayout =
        pointLayout._xRelativeToParentH = true
        Components.xph += value

      ypw: ypw = (value, pointLayout) ->
        value = preprocessValue value, pointLayout
        pointLayout._hasYLayout =
        pointLayout._yRelativeToParentW = true
        Components.ypw += value

      # children-relative components
      cs: (value, pointLayout) ->
        value = preprocessValue value, pointLayout
        pointLayout._hasXLayout =
        pointLayout._hasYLayout =
        pointLayout._xRelativeToChildrenW =
        pointLayout._yRelativeToChildrenH = true
        Components.xcw += value
        Components.ych += value

      xcw: xcw = (value, pointLayout) ->
        value = preprocessValue value, pointLayout
        pointLayout._hasXLayout =
        pointLayout._xRelativeToChildrenW = true
        Components.xcw += value

      ych: ych = (value, pointLayout) ->
        value = preprocessValue value, pointLayout
        pointLayout._hasYLayout =
        pointLayout._yRelativeToChildrenH = true
        Components.ych += value

      # Aliases
      plus:                     pts
      w:                        x
      h:                        y

      ww:                       xpw
      hh:                       yph
      xw:                       xpw
      yh:                       yph

      wh:                       xph
      hw:                       ypw
      xh:                       xph
      yw:                       ypw

      wpw:                      xpw
      hph:                      yph
      wcw:                      xcw
      hch:                      ych

      wph:                      xph
      hpw:                      ypw

      width:                    x
      height:                   y
      width_parentWidth:        xpw
      height_parentHeight:      yph
      width_childrenWidth:      xcw
      height_childrenHeight:    ych

      x_parentWidth:            xpw
      y_parentHeight:           yph
      x_childrenWidth:          xcw
      y_childrenHeight:         ych

  class PointLayout extends PointLayoutBase
    ###
    constructor inputs: (initializer, previousLayout)

    constant initializer: anything that isn't a function or an object that is a legal initializer for Points

      123         # number
      point 1, 2  # point
      [1, 2]      # [x, y] array
      "topLeft"   # named point
      "1, 2"      # "x, y" string which is parsed

    function initializer: (ps, cs) -> Point or Number

      layout is an abitrary function based on ps (parent-size) and cs (children-size) returning a point
      NOTE: this is the least efficient option UNLESS the function directly returns ps or cs.
      REASON: otherwise you are creating new points each time the function is called.

    options object initializer:

      # contains one or more of the following options

      # layoutX = x if isFunction x
      x:         (ps, cs) -> number

      # layoutX is the sum of:
      x:         k # -> k
      xpw:       k # -> k * ps.w
      xcw:       k # -> k * cs.w
      plus:      k # -> k
      ps:        k # -> k * ps.w
      cs:        k # -> k * cs.w

      # layoutY = y if isFunction y
      y:         (ps, cs) -> number

      # layoutY is the sum of:
      y:         k # -> k
      yph:       k # -> k * ps.h
      ych:       k # -> k * cs.h
      plus:      k # -> k
      ps:        k # -> k * ps.h
      cs:        k # -> k * cs.h

      # Alaises
      w:                        x
      h:                        y
      wpw:                      xpw
      hph:                      yph
      wcw:                      xcw
      hch:                      ych

      width:                    x
      height:                   y
      width_parentWidth:        xpw
      height_parentHeight:      yph
      width_childrenWidth:      xcw
      height_childrenHeight:    ych

      x_parentWidth:            xpw
      y_parentHeight:           yph
      x_childrenWidth:          xcw
      y_childrenHeight:         ych

    constructor option examples:

      ps:1, plus:100      # @layout = (ps) -> ps.add 100
      ps:1, cs:1          # @layout = (cs, ps) -> ps.add cs
      x:100, y:200        # @layout = -> point 100, 200
      w:100, h:200        # @layout = -> point 100, 200
      wpw:1, hch:1        # @layout = (ps, cs) -> point ps.x, cs.y

    NOTE: When providing custom functions, their dependency on parent or children size is auto-detected by:
      Evaluating f(point0, point0) and comparing it with nearInfinity for each of the 4 input values respectively.
      If your function varies at all in response to an input value, it should return something different for point0
      vs nearInfinity.

    ###
    constructor: (@initializer = point0, previousLayout)->
      super
      if isFunction @initializer
        @_setupFromFunction @initializer
      else if isPlainObject @initializer
        @_setupFromOptions @initializer, previousLayout
      else
        # Points, numbers, strings or arrays all get passed to point() and used as @initializer constant layout
        @_setupFromPoint @initializer

    toString: ->
      "PointLayout(#{@toStringLean()})"

    toStringLean: ->
      if @initializer
        if @initializer instanceof Point && @initializer.x == @initializer.y
          @initializer.x
        else
          inspectLean @initializer
      else '0'

    @getter
      inspectedInitializer: -> if @initializer then inspect @initializer else '0'
      plainObjects: ->
        v = @initializer || 0
        v = v.x if (v instanceof Point) && v.x == v.y
        v = v.getPlainObjects() if v.getPlainObjects
        v
      inspectObjects: ->
        if isPlainObject @initializer
          inspect: => inspectLean @initializer
        else if isFunction @initializer
          inspect: => @initializer.toString().replace /\s+/g, ' '
        else
          @initializer

    #############
    # PRIVATE
    #############

    _setupFromPoint: (val) ->
      @_hasXLayout = @_hasYLayout = true
      {x, y} = p = point val
      if isString val
        @layoutX = (ps) -> ps.x * x
        @layoutY = (ps) -> ps.y * y
        @layout  = (ps) -> ps.mul p
      else
        @layoutX = (ps) -> x
        @layoutY = (ps) -> y
        @layout  = (ps) -> p
      @initializer = p

    _setupFromFunction: (f) ->
      @_hasXLayout = @_hasYLayout = true
      if f.length == 1
        if isNumber f point0
          @layout = (ps) -> point f ps
          @layoutX = f
          @layoutY = f
        else
          @layout = f
          @layoutX = (ps) -> f(ps).x
          @layoutY = (ps) -> f(ps).y
      else
        if isNumber f point0, point0
          @layout = (ps, cs) -> point f ps, cs
          @layoutX = f
          @layoutY = f
        else
          @layout = f
          @layoutX = (ps, cs) -> f(ps, cs).x
          @layoutY = (ps, cs) -> f(ps, cs).y
      @_detectRelativity()

    _setupFromOptions: (options, previousLayout) ->
      Components.setupPointLayout @, options, previousLayout
