define [
  'art-atomic'
  'art-foundation'
], (Atomic, Foundation) ->

  {point, Point} = Atomic
  {point0} = Point
  {BaseObject, log, inspect, isFunction, isNumber, isPlainObject, nearInfinity, nearInfinityResult} = Foundation

  class PointLayoutBase extends BaseObject

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

      # NOTE: Chome is 3x faster if we just make these member functions, but Safari is 20% slower.
      # Since we are optimizing primarilly for Safari, and they are both still "fast", sticking with this.
      @layoutX =
      @layoutY = -> 0
      @layout  = (ps, cs) -> point @layoutX(ps, cs), @layoutY(ps, cs)

    interpolate: (toLayout, p) ->
      if p == 0 then @
      else if p == 1 then toLayout
      else new PointLayoutBase.InterpolatedPointLayout @, toLayout, p

    @getter inspectedString: -> @toString()

    inspect: -> @toString()

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
    @isParentWRelative:   isParentWRelative   = (f, baseline, baselinePoint, testPoint) -> f(testPoint, baselinePoint) != baseline
    @isParentHRelative:   isParentHRelative   = (f, baseline, baselinePoint, testPoint) -> f(testPoint, baselinePoint) != baseline
    @isChildrenWRelative: isChildrenWRelative = (f, baseline, baselinePoint, testPoint) -> f(baselinePoint, testPoint) != baseline
    @isChildrenHRelative: isChildrenHRelative = (f, baseline, baselinePoint, testPoint) -> f(baselinePoint, testPoint) != baseline

    _detectXRelativity: ->
      @_xRelativeToParentW   =
      @_xRelativeToParentH   =
      @_xRelativeToChildrenW =
      @_xRelativeToChildrenH = false

      layoutLength   = @layoutX.length
      layoutBaseline = @layoutX point0, point0
      nearInfinityBaseline = @layoutX nearInfinityPoint, nearInfinityPoint

      if layoutLength > 0
        @_xRelativeToParentW   = isParentWRelative(@layoutX, layoutBaseline, point0, nearInfinityPointX) || isParentWRelative(@layoutX, nearInfinityBaseline, nearInfinityPoint, nearInfinityPointY)
        @_xRelativeToParentH   = isParentHRelative(@layoutX, layoutBaseline, point0, nearInfinityPointY) || isParentHRelative(@layoutX, nearInfinityBaseline, nearInfinityPoint, nearInfinityPointX)
        if layoutLength == 1 && !@_xRelativeToParentW && !@_xRelativeToParentH
          console.warn """
            #{@}: horizontal/x/w layout function has 1 input, which suggests it should be parent-relative, but it doesn't appear to be.

            Resolution: If the input is unused, remove it. Otherwise, alter your function to respond differently for parent-sizes of 0 and children-sizes of near-infinity.

            layoutX: #{@layoutX}
            """

      if layoutLength > 1
        @_xRelativeToChildrenW = isChildrenWRelative(@layoutX, layoutBaseline, point0, nearInfinityPointX) || isChildrenWRelative(@layoutX, nearInfinityBaseline, nearInfinityPoint, nearInfinityPointY)
        @_xRelativeToChildrenH = isChildrenHRelative(@layoutX, layoutBaseline, point0, nearInfinityPointY) || isChildrenHRelative(@layoutX, nearInfinityBaseline, nearInfinityPoint, nearInfinityPointX)
        unless @_xRelativeToChildrenW || @_xRelativeToChildrenH
          console.warn """
            #{@}: horizontal/x/w layout function has 2 inputs, which suggests it should be child-relative, but it doesn't appear to be.

            Resolution: If the second input is unused, remove it. Otherwise, alter your function to respond differently for children-sizes of 0 vs near-infinity when parent-size is 0.

            layoutX: #{@layoutX}
            """

    _detectYRelativity: ->
      @_yRelativeToParentW   =
      @_yRelativeToParentH   =
      @_yRelativeToChildrenW =
      @_yRelativeToChildrenH = false

      layoutLength   = @layoutY.length
      layoutBaseline = @layoutY point0, point0
      nearInfinityBaseline = @layoutY nearInfinityPoint, nearInfinityPoint

      if layoutLength > 0
        @_yRelativeToParentW   = isParentWRelative(@layoutY, layoutBaseline, point0, nearInfinityPointX) || isParentWRelative(@layoutY, nearInfinityBaseline, nearInfinityPoint, nearInfinityPointY)
        @_yRelativeToParentH   = isParentHRelative(@layoutY, layoutBaseline, point0, nearInfinityPointY) || isParentHRelative(@layoutY, nearInfinityBaseline, nearInfinityPoint, nearInfinityPointX)
        if layoutLength == 1 && !@_yRelativeToParentW && !@_yRelativeToParentH
          console.warn "#{@}: vertical/y/h layout function has 1 input, which suggests
            it should be parent-relative, but it doesn't appear to be.
            \n\nResolution: If the input
            is unused, remove it. Otherwise, alter your function to respond differently
            for parent-sizes of 0 and children-sizes of near-infinity."

      if layoutLength > 1
        @_yRelativeToChildrenW = isChildrenWRelative(@layoutY, layoutBaseline, point0, nearInfinityPointX) || isChildrenWRelative(@layoutY, nearInfinityBaseline, nearInfinityPoint, nearInfinityPointY)
        @_yRelativeToChildrenH = isChildrenHRelative(@layoutY, layoutBaseline, point0, nearInfinityPointY) || isChildrenHRelative(@layoutY, nearInfinityBaseline, nearInfinityPoint, nearInfinityPointX)
        unless @_yRelativeToChildrenW || @_yRelativeToChildrenH
          console.warn "#{@}: vertical/y/h layout function has 2 inputs, which suggests
            it should be child-relative, but it doesn't appear to be.
            \n\nResolution: If the second input
            is unused, remove it. Otherwise, alter your function to respond differently
            for children-sizes of 0 vs near-infinity when parent-size is 0."

    _detectRelativity: ->
      @_detectXRelativity()
      @_detectYRelativity()
