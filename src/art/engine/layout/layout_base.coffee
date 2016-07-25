define [
  'art-foundation'
  'art-atomic'
], (Foundation, Atomic) ->
  {BaseObject, isPlainObject, log, isFunction, nearInfinity, nearInfinityResult, abs} = Foundation
  {point} = Atomic


  # nearInfinity NOTES:
  # http://www.html5rocks.com/en/tutorials/speed/v8/
  # Chrome uses signed 31bit integers for "optimized ints"; this is the largest optimized integer value:
  #   Math.pow(2, 30) - 1
  # However, its nice to have a round number to make it clear it is a special number.
  # We don't use Inifinity because Infinity * 0 is NaN - we want it to be 0.
  # ...
  # 2014-12-20 SBD
  # On further reflection, these numbers are going to be floating-point anyway, so lets make them big.

  class LayoutBase extends BaseObject
    @nearInfinity:        nearInfinity
    @nearInfinityResult:  nearInfinityResult
    @nearInfinitePoint:   nearInfinitePoint = point nearInfinity
    @nearInfiniteSize:    nearInfinitePoint
    @isInfiniteResult:    (x) -> abs(x) >= nearInfinityResult

    @InterpolatedLayout = null # set to InterpolatedLayout by InterpolatedLayout
    @LinearLayout = null # set to LinearLayout by LinearLayout

    @mergeLayouts: (newLayout, oldLayout, forceFull) ->
      if isPlainObject newLayout
        new LayoutBase.LinearLayout newLayout, oldLayout, forceFull #, true
      else if !newLayout || newLayout.getHasFullLayout() || !oldLayout
        newLayout
      else if newLayout instanceof LayoutBase.LinearLayout
        new LayoutBase.LinearLayout newLayout.options, oldLayout, forceFull
      else
        console.error newLayout:newLayout, oldLayout:oldLayout
        throw new Error "mergeLayout requires newLayout to be: null, a plain object, instanceof LinearLayout or newLayout.hasFullLayout == true"

    @getter """
      options
      sizeChildRelative
      locationParentRelative
      sizeParentRelative
      widthParentRelative
      heightParentRelative
      hasXLayout
      hasYLayout
      hasWLayout
      hasHLayout
      hasFullLayout
      """

    @getter
      parentRelative: -> @_locationParentRelative || @_sizeParentRelative

    constructor: ->
      super
      @_hasFullLayout =
        @_hasXLayout &&
        @_hasYLayout &&
        @_hasWLayout &&
        @_hasHLayout


    sizeLayoutCircular: (parentLayout) ->
      return false unless @_sizeParentRelative && parentLayout?._sizeChildRelative
      ww = @getWw()
      hh = @getHh()
      hw = @getHw()
      wh = @getWh()

      wcw = parentLayout.getWcw()
      hch = parentLayout.getHch()
      wch = parentLayout.getWch()
      hcw = parentLayout.getHcw()

      !!(
        (ww && wcw) ||
        (hh && hch) ||
        (hw && wch) ||
        (wh && hcw) ||
        (wh && hch && hw && wcw) ||
        (ww && wch && hh && hcw)
      )

    locationLayoutCircular: (parentLayout) ->
      return false unless @_locationParentRelative && parentLayout?._sizeChildRelative
      xw = @getXw()
      yh = @getYh()
      yw = @getYw()
      xh = @getXh()

      wcw = parentLayout.getWcw()
      hch = parentLayout.getHch()
      wch = parentLayout.getWch()
      hcw = parentLayout.getHcw()

      !!(
        (xw && wcw) ||
        (yh && hch) ||
        (yw && wch) ||
        (xh && hcw) ||
        (xh && hch && yw && wcw) ||
        (xw && wch && yh && hcw)
      )

    areaLayoutCircular: (parentLayout) ->
      return false unless (@_locationParentRelative || @_sizeParentRelative) && parentLayout?._sizeChildRelative
      ww = @getWw() || @getXw()
      hh = @getHh() || @getYh()
      hw = @getHw() || @getXw()
      wh = @getWh() || @getYh()
      wcw = parentLayout.getWcw()
      hch = parentLayout.getHch()
      wch = parentLayout.getWch()
      hcw = parentLayout.getHcw()

      !!(
        (ww && wcw) ||
        (hh && hch) ||
        (hw && wch) ||
        (wh && hcw) ||
        (wh && hch && hw && wcw) ||
        (ww && wch && hh && hcw)
      )


    interpolate: (toLayout, p) ->
      if p == 0
        @
      else if p == 1
        toLayout
      else
        new LayoutBase.InterpolatedLayout @, toLayout, p
