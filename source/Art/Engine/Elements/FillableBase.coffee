Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
FilterAndFillableBase = require './FilterAndFillableBase'
{PointLayout, PointLayoutBase} = require '../Layout'
{log, isPlainObject, min, max, createWithPostCreate, isNumber, merge} = Foundation
{rgbColor, Color, point, Point, rect, Rectangle, matrix, Matrix, point0, point1} = Atomic
{GradientFillStyle} = Canvas
# can be a gradient fill or a solid-color fill
# if the @gradient property is set (including indirectly by setting the @colors property), then it is a gradient
# Otherwise, the @color property is used and @from and @to properties are ignored.
module.exports = createWithPostCreate class FillableBase extends FilterAndFillableBase
  @registerWithElementFactory: -> @ != FillableBase

  @getter
    cacheable: -> @getHasChildren()

  defaultOffset = new PointLayout y: 2
  noShadow =
    color: rgbColor 0,0,0,0
    blur: 0
    offset: new PointLayout 0
  @drawProperty
    # from:   default: "topLeft", preprocess: (v) -> point v
    # to:     default: null, preprocess: (v) -> v? && point v
    from: preprocess: (v) -> v && if v instanceof PointLayoutBase then v else new PointLayout v
    to:   preprocess: (v) -> v && if v instanceof PointLayoutBase then v else new PointLayout v

    gradientRadius: default: null
    shadow:
      default: null
      validate: (v) -> !v || v == true || isPlainObject v
      preprocess: (v) ->
        return null unless v
        {color, offset, blur} = v
        color = rgbColor color || "#0007"
        return null if color.a < 1/255
        offset = if offset?
          if offset instanceof PointLayoutBase
            offset
          else
            new PointLayout offset
        else
          defaultOffset

        blur = 4 unless blur?

        blur: blur
        offset: offset
        color: color

  @getter
    normalizedShadow: (pending)->
      shadow = @getShadow pending
      return null if !shadow || shadow == noShadow
      {offset} = shadow
      x = offset.layoutX @_currentSize
      y = offset.layoutY @_currentSize
      merge shadow,
        offsetX: x
        offsetY: y

  _expandRectangleByShadow: (r, pending, normalizedShadow) ->
    return r unless normalizedShadow
    {x, y, w, h} = r
    {blur, offsetX, offsetY} = normalizedShadow
    offsetX ||= 0
    offsetY ||= 0
    blur ||= 0
    expandLeft    = max 0, blur - offsetX
    expandTop     = max 0, blur - offsetY
    expandRight   = max 0, blur + offsetX
    expandBottom  = max 0, blur + offsetY
    r.with(
      x - expandLeft
      y - expandTop
      w + expandLeft + expandRight
      h + expandTop + expandBottom
    )

  @virtualProperty
    drawAreaPadding: (pending) -> 0
    baseDrawArea: (pending) ->
      @_expandRectangleByShadow @getPreFilteredBaseDrawArea(pending),
        pending
        @getNormalizedShadow pending

  _prepareDrawOptions: (drawOptions, compositeMode, opacity)->
    super
    drawOptions.shadow = @normalizedShadow
