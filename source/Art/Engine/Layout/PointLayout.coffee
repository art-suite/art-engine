{point, Point} = require 'art-atomic'
{point0} = Point
{
  defineModule, log, inspect, inspectLean, isFunction, isNumber, isString, isPlainObject, min, max
} = require 'art-standard-lib'

# a singleton to help make initializing from component-options fast
class Components

  @setupPointLayout: (newPointLayout, options, previousLayout) ->
    maxLayout = newPointLayout.maxLayout = if options.max then new PointLayout options.max
    for k, v of options
      applyFunction = applyComponentsFunctions[k]
      throw new Error "invalid PointLayout component: #{inspect k} in #{inspect options}" unless applyFunction
      applyFunction v, newPointLayout

    if !newPointLayout._hasXLayout && previousLayout?._hasXLayout
      newPointLayout.copyXLayout previousLayout

    if !newPointLayout._hasYLayout && previousLayout?._hasYLayout
      newPointLayout.copyYLayout previousLayout

    newPointLayout.mergeInLayoutRelativity maxLayout if maxLayout
    newPointLayout


  ###################
  # private
  ###################

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
      pointLayout.x += value.x
      pointLayout.y += value.y

    x: x = (value, pointLayout) ->
      pointLayout._hasXLayout = true
      if isFunction value
        pointLayout.customLayoutX = value
      else
        value = preprocessValue value, pointLayout
        pointLayout.x += value

    y: y = (value, pointLayout) ->
      pointLayout._hasYLayout = true
      if isFunction value
        pointLayout.customLayoutY = value
      else
        value = preprocessValue value, pointLayout
        pointLayout.y += value

    # parent-relative components
    ps: (value, pointLayout) ->
      value = preprocess2dValue value, pointLayout
      pointLayout._hasXLayout =
      pointLayout._hasYLayout =
      pointLayout._xRelativeToParentW =
      pointLayout._yRelativeToParentH = true
      pointLayout.xpw += value.x
      pointLayout.yph += value.y

    xpw: xpw = (value, pointLayout) ->
      value = preprocessValue value, pointLayout
      pointLayout._hasXLayout =
      pointLayout._xRelativeToParentW = true
      pointLayout.xpw += value

    yph: yph = (value, pointLayout) ->
      value = preprocessValue value, pointLayout
      pointLayout._hasYLayout =
      pointLayout._yRelativeToParentH = true
      pointLayout.yph += value

    xph: xph = (value, pointLayout) ->
      value = preprocessValue value, pointLayout
      pointLayout._hasXLayout =
      pointLayout._xRelativeToParentH = true
      pointLayout.xph += value

    ypw: ypw = (value, pointLayout) ->
      value = preprocessValue value, pointLayout
      pointLayout._hasYLayout =
      pointLayout._yRelativeToParentW = true
      pointLayout.ypw += value

    # children-relative components
    cs: (value, pointLayout) ->
      value = preprocess2dValue value, pointLayout
      pointLayout._hasXLayout =
      pointLayout._hasYLayout =
      pointLayout._xRelativeToChildrenW =
      pointLayout._yRelativeToChildrenH = true
      pointLayout.xcw += value.x
      pointLayout.ych += value.y

    xcw: xcw = (value, pointLayout) ->
      value = preprocessValue value, pointLayout
      pointLayout._hasXLayout =
      pointLayout._xRelativeToChildrenW = true
      pointLayout.xcw += value

    ych: ych = (value, pointLayout) ->
      value = preprocessValue value, pointLayout
      pointLayout._hasYLayout =
      pointLayout._yRelativeToChildrenH = true
      pointLayout.ych += value

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

defineModule module, class PointLayout extends PointLayoutBase = require './PointLayoutBase'

  @pointLayout: pointLayout = (init, previousLayout) ->
    unless init?
      if previousLayout?
        pointLayout previousLayout
      else
        new PointLayout()

    else if init instanceof PointLayoutBase
      init
    else
      new PointLayout init, previousLayout

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
    @_reset()

    if isFunction @initializer
      @_setupFromFunction @initializer
    else if isPlainObject @initializer
      @_setupFromOptions @initializer, previousLayout
    else
      # Points, numbers, strings or arrays all get passed to point() and used as @initializer constant layout
      @_setupFromPoint @initializer

  _reset: ->
    @maxLayout = null
    @customLayout = null
    @customLayoutX = null
    @customLayoutY = null
    @x   =
    @xpw =
    @xph =
    @xcw =
    @y   =
    @yph =
    @ypw =
    @ych = 0.0

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

  layoutX: (ps, cs) ->
    # copy all members we use into this closure
    # do not access anything on '@' inside the functions created velow
    {x, xpw, xph, xcw, customLayout, customLayoutX, maxLayout} = @

    if customLayout       then customLayout(ps, cs).x
    else if customLayoutX then customLayoutX ps, cs
    else
      out = x
      out += xpw * ps.x + xph * ps.y if ps?
      out += xcw * cs.x if cs?

      if maxLayout?.getHasXLayout()
        min out, maxLayout.layoutX ps
      else
        out

  layoutY: (ps, cs) ->
    {y, yph, ypw, ych, customLayout, customLayoutY, maxLayout} = @   # copy all members we use into this closure

    if customLayout       then customLayout(ps, cs).y
    else if customLayoutY then customLayoutY ps, cs
    else
      out = y
      out += yph * ps.y + ypw * ps.x if ps?
      out += ych * cs.y if cs?

      if maxLayout?.getHasYLayout()
        min out, maxLayout.layoutY ps
      else
        out

  copyXLayout: (pointLayout) ->
    @_hasXLayout = true
    if pointLayout.maxLayout || pointLayout.customLayout
      @customLayoutY = fastBind pointLayout.layoutX, pointLayout
    else
      {
        @x
        @xpw
        @xph
        @xcw
        @customLayoutX
      } = pointLayout

    @_copyXRelativity pointLayout

  copyYLayout: (pointLayout) ->
    @_hasYLayout = true
    if pointLayout.maxLayout || pointLayout.customLayout
      @customLayoutY = fastBind pointLayout.layoutY, pointLayout
    else
      {
        @y
        @yph
        @ypw
        @ych
        @customLayoutY
      } = pointLayout

    @_copyYRelativity pointLayout

  #############
  # PRIVATE
  #############

  _setupFromPoint: (val) ->
    @_hasXLayout = @_hasYLayout = true
    if isNumber val
      @x = @y = val
    else
      {x, y} = @initializer = point val
      if isString val
        # if using a named point (like 'topCenter'), we take it as parent-relative
        @xpw = x
        @yph = y
      else
        @x = x
        @y = y

  _setupFromFunction: (layoutFunction) ->
    @_hasXLayout = @_hasYLayout = true
    if isNumber layoutFunction point0, point0
      @customLayoutX = layoutFunction
      @customLayoutY = layoutFunction
    else
      @layout = @customLayout = layoutFunction

    @_detectRelativity()

  _setupFromOptions: (options, previousLayout) ->
    Components.setupPointLayout @, options, previousLayout
    @_detectXRelativity() if @customLayoutX
    @_detectYRelativity() if @customLayoutY