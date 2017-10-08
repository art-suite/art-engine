{point, Point} = require 'art-atomic'
{point0} = Point
{
  log, inspect, isFunction, isNumber, isPlainObject, nearInfinity, nearInfinityResult
  inspectedObjectLiteral
} = require 'art-standard-lib'
{BaseClass} = require 'art-class-system'

module.exports = class PointLayoutBase extends BaseClass

  constructor: (a, previousLayout)->
    # super # commenting this out makes Safari 2x faster
    @_xRelativeToParentW   =
    @_xRelativeToParentH   =
    @_yRelativeToParentW   =
    @_yRelativeToParentH   =
    @_xRelativeToChildrenW =
    @_xRelativeToChildrenH =
    @_yRelativeToChildrenW =
    @_yRelativeToChildrenH = false

    @_hasXLayout = @_hasYLayout = false
    @_inheritedXLayout = @_inheritedYLayout = false

    # NOTE: Chome is 3x faster if we just make these member functions, but Safari is 20% slower.
    # Since we are optimizing primarilly for Safari, and they are both still "fast", sticking with this.

  layout: (ps, cs) -> point @layoutX(ps, cs), @layoutY(ps, cs)

  mergeInLayoutRelativity: (layout) ->
    @_xRelativeToParentW   ||= layout._xRelativeToParentW
    @_xRelativeToParentH   ||= layout._xRelativeToParentH
    @_yRelativeToParentW   ||= layout._yRelativeToParentW
    @_yRelativeToParentH   ||= layout._yRelativeToParentH
    @_xRelativeToChildrenW ||= layout._xRelativeToChildrenW
    @_xRelativeToChildrenH ||= layout._xRelativeToChildrenH
    @_yRelativeToChildrenW ||= layout._yRelativeToChildrenW
    @_yRelativeToChildrenH ||= layout._yRelativeToChildrenH

  interpolate: (toLayout, p) ->
    if p == 0 then @
    else if p == 1 then toLayout
    else new PointLayoutBase.InterpolatedPointLayout @, toLayout, p

  @getter inspectedString: -> @toString()

  inspect: -> @toString()

  _copyXRelativity: (sourceLayout) ->
    @_xRelativeToParentW   = sourceLayout._xRelativeToParentW
    @_xRelativeToParentH   = sourceLayout._xRelativeToParentH
    @_xRelativeToChildrenW = sourceLayout._xRelativeToChildrenW
    @_xRelativeToChildrenH = sourceLayout._xRelativeToChildrenH

  _copyYRelativity: (sourceLayout) ->
    @_yRelativeToParentW   = sourceLayout._yRelativeToParentW
    @_yRelativeToParentH   = sourceLayout._yRelativeToParentH
    @_yRelativeToChildrenW = sourceLayout._yRelativeToChildrenW
    @_yRelativeToChildrenH = sourceLayout._yRelativeToChildrenH

  @getter
    inspectedObjects: -> inspectedObjectLiteral @toString()

  @getter """
    xRelativeToParentW
    xRelativeToParentH
    yRelativeToParentW
    yRelativeToParentH
    xRelativeToChildrenW
    xRelativeToChildrenH
    yRelativeToChildrenW
    yRelativeToChildrenH
    hasXLayout
    hasYLayout
    """

  @getter
    hasFullLayout:      -> @_hasXLayout           && @_hasYLayout
    hasLayout:          -> @_hasXLayout           || @_hasYLayout
    parentRelative:     -> @_xRelativeToParentH   || @_xRelativeToParentW   || @_yRelativeToParentH   || @_yRelativeToParentW
    childrenRelative:   -> @_xRelativeToChildrenH || @_xRelativeToChildrenW || @_yRelativeToChildrenH || @_yRelativeToChildrenW
    xParentRelative:    -> @_xRelativeToParentH   || @_xRelativeToParentW
    yParentRelative:    -> @_yRelativeToParentH   || @_yRelativeToParentW
    xChildrenRelative:  -> @_xRelativeToChildrenH || @_xRelativeToChildrenW
    yChildrenRelative:  -> @_yRelativeToChildrenH || @_yRelativeToChildrenW

  layoutIsCircular: (parentLayout) ->
    return false unless parentLayout
    xpx = @_xRelativeToParentW
    xpy = @_xRelativeToParentH
    ypx = @_yRelativeToParentW
    ypy = @_yRelativeToParentH

    xcx = parentLayout.getXRelativeToChildrenW()
    xcy = parentLayout.getXRelativeToChildrenH()
    ycx = parentLayout.getYRelativeToChildrenW()
    ycy = parentLayout.getYRelativeToChildrenH()

    result = !!(
      (xpx && xcx) ||
      (xpy && ycx) ||
      (ypy && ycy) ||
      (ypx && xcy) ||
      (xpy && ycy && ypx && xcy) ||
      (xpx && xcy && ypy && ycx)
    )

    result

  #############
  # PRIVATE
  #############

  nearInfinityPoint = point nearInfinity, nearInfinity
  nearInfinityPointX = point0.withX nearInfinity
  nearInfinityPointY = point0.withY nearInfinity
  isParentRelative:   (fName, baseline, baselinePoint, testPoint) -> @[fName](testPoint, baselinePoint) != baseline
  isChildrenRelative: (fName, baseline, baselinePoint, testPoint) -> @[fName](baselinePoint, testPoint) != baseline

  _detectXRelativity: ->
    layoutBaseline = @layoutX point0, point0
    nearInfinityBaseline = @layoutX nearInfinityPoint, nearInfinityPoint

    @_xRelativeToParentW   = @isParentRelative(   "layoutX", layoutBaseline, point0, nearInfinityPointX) || @isParentRelative(  "layoutX", nearInfinityBaseline, nearInfinityPoint, nearInfinityPointY)
    @_xRelativeToParentH   = @isParentRelative(   "layoutX", layoutBaseline, point0, nearInfinityPointY) || @isParentRelative(  "layoutX", nearInfinityBaseline, nearInfinityPoint, nearInfinityPointX)
    @_xRelativeToChildrenW = @isChildrenRelative( "layoutX", layoutBaseline, point0, nearInfinityPointX) || @isChildrenRelative("layoutX", nearInfinityBaseline, nearInfinityPoint, nearInfinityPointY)
    @_xRelativeToChildrenH = @isChildrenRelative( "layoutX", layoutBaseline, point0, nearInfinityPointY) || @isChildrenRelative("layoutX", nearInfinityBaseline, nearInfinityPoint, nearInfinityPointX)

  _detectYRelativity: ->
    layoutBaseline = @layoutY point0, point0
    nearInfinityBaseline = @layoutY nearInfinityPoint, nearInfinityPoint

    @_yRelativeToParentW   = @isParentRelative(   "layoutY", layoutBaseline, point0, nearInfinityPointX) || @isParentRelative(  "layoutY", nearInfinityBaseline, nearInfinityPoint, nearInfinityPointY)
    @_yRelativeToParentH   = @isParentRelative(   "layoutY", layoutBaseline, point0, nearInfinityPointY) || @isParentRelative(  "layoutY", nearInfinityBaseline, nearInfinityPoint, nearInfinityPointX)
    @_yRelativeToChildrenW = @isChildrenRelative( "layoutY", layoutBaseline, point0, nearInfinityPointX) || @isChildrenRelative("layoutY", nearInfinityBaseline, nearInfinityPoint, nearInfinityPointY)
    @_yRelativeToChildrenH = @isChildrenRelative( "layoutY", layoutBaseline, point0, nearInfinityPointY) || @isChildrenRelative("layoutY", nearInfinityBaseline, nearInfinityPoint, nearInfinityPointX)

  _detectRelativity: ->
    @_detectXRelativity()
    @_detectYRelativity()
