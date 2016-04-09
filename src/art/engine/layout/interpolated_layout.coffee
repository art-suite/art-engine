define [
  'art-foundation'
  'art-atomic'
  './layout_base'
], (Foundation, Atomic, LayoutBase) ->

  rubyOr = Foundation.Ruby.or

  {point, Point, rect, Rectangle, matrix, Matrix} = Atomic
  {point0} = Point
  {inspectLean, max, log, flatten, compact, time, clone, inspect, min, max, flatten, isPlainObject} = Foundation

  class LayoutBase.InterpolatedLayout extends LayoutBase

    constructor: (layout1, layout2, p)->
      @layout1 = layout1
      @layout2 = layout2
      @p = p

      @_hasXLayout    = @layout1.getHasXLayout() || @layout2.getHasXLayout()
      @_hasYLayout    = @layout1.getHasYLayout() || @layout2.getHasYLayout()
      @_hasWLayout    = @layout1.getHasWLayout() || @layout2.getHasWLayout()
      @_hasHLayout    = @layout1.getHasHLayout() || @layout2.getHasHLayout()

      @_sizeChildRelative      = @layout1.getSizeChildRelative()      || @layout2.getSizeChildRelative()
      @_locationParentRelative = @layout1.getLocationParentRelative() || @layout2.getLocationParentRelative()
      @_sizeParentRelative     = @layout1.getSizeParentRelative()     || @layout2.getSizeParentRelative()

      # layout 2 has priority; options is set to reflect the p == 1 state.
      @_options = layout2.mergeOptions layout1

      super

    toString: (showBracketedIfNotPresent)->
      "(#{@layout1.toString showBracketedIfNotPresent} * #{1 - @p} + " +
      "#{@layout2.toString showBracketedIfNotPresent} * #{@p})"

    inspect: -> @toString()

    @getter
      x:  -> @layout1.getX()  + @layout2.getX()
      y:  -> @layout1.getY()  + @layout2.getY()
      w:  -> @layout1.getW()  + @layout2.getW()
      h:  -> @layout1.getH()  + @layout2.getH()
      xw: -> @layout1.getXw() + @layout2.getXw()
      xh: -> @layout1.getXh() + @layout2.getXh()
      yh: -> @layout1.getYh() + @layout2.getYh()
      yw: -> @layout1.getYw() + @layout2.getYw()
      ww: -> @layout1.getWw() + @layout2.getWw()
      wh: -> @layout1.getWh() + @layout2.getWh()
      hh: -> @layout1.getHh() + @layout2.getHh()
      hw: -> @layout1.getHw() + @layout2.getHw()
      wcw: -> @layout1.getWcw() + @layout2.getWcw()
      wch: -> @layout1.getWch() + @layout2.getWch()
      hch: -> @layout1.getHch() + @layout2.getHch()
      hcw: -> @layout1.getHcw() + @layout2.getHcw()

    mergeOptions: (previousOptions) ->
      @_options.mergeOptions previousOptions

    #####################################
    # transform Location
    #####################################

    interpolate1D: (hasFrom, hasTo, from, to) ->
      if hasFrom
        if hasTo
          (to - from) * @p + from
        else from
      else to

    transformLocationX: (parentSize) ->
      @interpolate1D(
        @layout1.getHasXLayout()
        @layout2.getHasXLayout()
        @layout1.transformLocationX parentSize
        @layout2.transformLocationX parentSize
      )

    transformLocationY: (parentSize) ->
      @interpolate1D(
        @layout1.getHasYLayout()
        @layout2.getHasYLayout()
        @layout1.transformLocationY parentSize
        @layout2.transformLocationY parentSize
      )

    transformLocation: (parentSize) ->
      point(
        @transformLocationX parentSize
        @transformLocationY parentSize
      )

    #####################################
    # transform Size
    #####################################

    transformSizeX: (parentSize, childrenSize) ->
      @interpolate1D(
        @layout1.getHasWLayout()
        @layout2.getHasWLayout()
        @layout1.transformSizeX parentSize, childrenSize
        @layout2.transformSizeX parentSize, childrenSize
      )

    transformSizeY: (parentSize, childrenSize) ->
      @interpolate1D(
        @layout1.getHasHLayout()
        @layout2.getHasHLayout()
        @layout1.transformSizeY parentSize, childrenSize
        @layout2.transformSizeY parentSize, childrenSize
      )

    transformSize: (parentSize, childrenSize = point0) ->
      point(
        @transformSizeX parentSize, childrenSize
        @transformSizeY parentSize, childrenSize
      )
