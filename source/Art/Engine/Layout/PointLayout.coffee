Atomic = require 'art-atomic'
Foundation = require 'art-foundation'
PointLayoutBase = require './PointLayoutBase'

{point, Point} = Atomic
{point0} = Point
{BaseObject, defineModule, log, inspect, inspectLean, isFunction, isNumber, isString, isPlainObject, min, max} = Foundation

# a singleton to help make initializing from component-options fast
class Components

  returnZero = -> 0

  @setupPointLayout: (newPointLayout, options, previousLayout) ->
    maxLayout = if options.max then new PointLayout options.max
    @_reset()
    for k, v of options
      applyFunction = applyComponentsFunctions[k]
      throw new Error "invalid PointLayout component: #{inspect k} in #{inspect options}" unless applyFunction
      applyFunction v, newPointLayout

    newPointLayout.layoutX = if newPointLayout._hasXLayout
      layoutX = @_buildXLayoutFromComponents maxLayout
      newPointLayout._detectXRelativity layoutX if @needToDetectXRelativity
      layoutX
    else if previousLayout?._hasXLayout
      newPointLayout._inheritedXLayout = previousLayout
      newPointLayout._hasXLayout = true
      newPointLayout._copyXRelativity previousLayout
      previousLayout.layoutX
    else
      returnZero

    newPointLayout.layoutY = if newPointLayout._hasYLayout
      layoutY = @_buildYLayoutFromComponents maxLayout
      newPointLayout._detectYRelativity layoutY if @needToDetectYRelativity
      layoutY
    else if previousLayout?._hasYLayout
      newPointLayout._inheritedYLayout = previousLayout
      newPointLayout._hasYLayout = true
      newPointLayout._copyYRelativity previousLayout
      previousLayout.layoutY
    else
      returnZero

    newPointLayout.mergeInLayoutRelativity maxLayout if maxLayout
    newPointLayout


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

  preprocess2dValue = (value, pointLayout) ->
    point value

  @_applyComponentsFunctions: applyComponentsFunctions =

    max: (value, pointLayout) ->
      # noop - this exists to validate it is a legal option, but it is handled elsewhere

    # all layout is in length-units of "pts" (points).
    # Points == Pixels for non-retina screens (pixelsPerPoint == 1)
    # provide numbers or 2d Points (not to be confused with pts, the length unit) to add to your layout.
    pts: pts = (value, pointLayout) ->
      value = preprocess2dValue value, pointLayout
      pointLayout._hasXLayout =
      pointLayout._hasYLayout = true
      Components.x += value.x
      Components.y += value.y

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
      value = preprocess2dValue value, pointLayout
      pointLayout._hasXLayout =
      pointLayout._hasYLayout =
      pointLayout._xRelativeToParentW =
      pointLayout._yRelativeToParentH = true
      Components.xpw += value.x
      Components.yph += value.y

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
      value = preprocess2dValue value, pointLayout
      pointLayout._hasXLayout =
      pointLayout._hasYLayout =
      pointLayout._xRelativeToChildrenW =
      pointLayout._yRelativeToChildrenH = true
      Components.xcw += value.x
      Components.ych += value.y

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
    wph:                      xph
    hpw:                      ypw

    wcw:                      xcw
    hch:                      ych

    width:                    x
    height:                   y
    widthParentWidth:         xpw
    heightParentHeight:       yph
    widthChildrenWidth:       xcw
    heightChildrenHeight:     ych

    xParentWidth:             xpw
    yParentHeight:            yph

defineModule module, class PointLayout extends PointLayoutBase
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
    out = if @initializer
      if @initializer instanceof Point && @initializer.x == @initializer.y
        @initializer.x
      else
        inspectLean @initializer
    else '0'
    out += ", inheritedXLayout: #{@_inheritedXLayout}" if @_inheritedXLayout
    out += ", inheritedYLayout: #{@_inheritedYLayout}" if @_inheritedYLayout
    out

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

  _setupFromFunction: (layoutFunction) ->
    @_hasXLayout = @_hasYLayout = true
    if layoutFunction.length == 1
      if isNumber layoutFunction point0
        @layout = (ps) -> point layoutFunction ps
        @layoutX = layoutFunction
        @layoutY = layoutFunction
      else
        @layout = layoutFunction
        @layoutX = (ps) -> layoutFunction(ps).x
        @layoutY = (ps) -> layoutFunction(ps).y
    else
      if isNumber layoutFunction point0, point0
        @layout = (ps, cs) -> point layoutFunction ps, cs
        @layoutX = layoutFunction
        @layoutY = layoutFunction
      else
        @layout = layoutFunction
        @layoutX = (ps, cs) -> layoutFunction(ps, cs).x
        @layoutY = (ps, cs) -> layoutFunction(ps, cs).y
    @_detectRelativity()

  _setupFromOptions: (options, previousLayout) ->
    Components.setupPointLayout @, options, previousLayout
