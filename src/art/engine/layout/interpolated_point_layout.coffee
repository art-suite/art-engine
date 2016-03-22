Foundation = require 'art-foundation'
PointLayoutBase = require './point_layout_base'

{log} = Foundation

module.exports = class InterpolatedPointLayout extends PointLayoutBase
  PointLayoutBase.InterpolatedPointLayout = @ # resolve circular dependency

  constructor: (layout1, layout2, p)->
    super
    @layout1 = layout1
    @layout2 = layout2
    @p = p

    @_hasXLayout           = @layout1._hasXLayout      || !@layout2._hasXLayout
    @_hasYLayout           = @layout1._hasYLayout      || !@layout2._hasYLayout
    @_xRelativeToParentW   = @layout1._xRelativeToParentW   || @layout2._xRelativeToParentW
    @_xRelativeToParentH   = @layout1._xRelativeToParentH   || @layout2._xRelativeToParentH
    @_yRelativeToParentW   = @layout1._yRelativeToParentW   || @layout2._yRelativeToParentW
    @_yRelativeToParentH   = @layout1._yRelativeToParentH   || @layout2._yRelativeToParentH
    @_xRelativeToChildrenW = @layout1._xRelativeToChildrenW || @layout2._xRelativeToChildrenW
    @_xRelativeToChildrenH = @layout1._xRelativeToChildrenH || @layout2._xRelativeToChildrenH
    @_yRelativeToChildrenW = @layout1._yRelativeToChildrenW || @layout2._yRelativeToChildrenW
    @_yRelativeToChildrenH = @layout1._yRelativeToChildrenH || @layout2._yRelativeToChildrenH

    @layoutX = (ps, cs) ->
      interpolate1D p,
        layout1._hasXLayout
        layout2._hasXLayout
        layout1.layoutX ps, cs
        layout2.layoutX ps, cs

    @layoutY = (ps, cs) ->
      interpolate1D p,
        layout1._hasYLayout
        layout2._hasYLayout
        layout1.layoutY ps, cs
        layout2.layoutY ps, cs

  toString: -> "InterpolatedPointLayout(from: (#{@layout1.toStringLean()}), to: (#{@layout2.toStringLean()}), #{@p*100 | 0}%)"

  @getter inspectedString: -> @toString()

  inspect: (inspector)->
    v = @inspect2()
    inspector?.put v
    v

  inspect2: -> @toString()

  @interpolate1D: interpolate1D = (p, hasFrom, hasTo, from, to) ->
    if hasFrom
      if hasTo
        (to - from) * p + from
      else from
    else to
