Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
Base = require './base'
{log, isPlainObject, min, max, createWithPostCreate} = Foundation
{color, Color, point, Point, rect, Rectangle, matrix, Matrix, point0, point1} = Atomic
{GradientFillStyle} = Canvas

# can be a gradient fill or a solid-color fill
# if the @gradient property is set (including indirectly by setting the @colors property), then it is a gradient
# Otherwise, the @color property is used and @from and @to properties are ignored.
module.exports = createWithPostCreate class FillableBase extends Base
  @registerWithElementFactory: -> @ != FillableBase

  @getter
    cacheable: -> @getHasChildren()

  @drawProperty
    gradient: default: null, validate: (v) -> !v || v instanceof GradientFillStyle
    from:   default: "topLeft", preprocess: (v) -> point v
    to:     default: "bottomLeft", preprocess: (v) -> point v
    shadow:
      default: null
      validate: (v) -> !v || isPlainObject v

  @virtualProperty
    colors:
      getterNew: (pending) -> @getState(pending).gradient?.colors
      setter: (v) -> @setGradient v && new GradientFillStyle point0, point1, v

  _expandRectangleByShadow: _expandRectangleByShadow = (r, shadow) ->
    return r unless shadow
    {x, y, w, h} = r
    {blur, offsetX, offsetY} = shadow
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

  getBaseDrawArea:        -> _expandRectangleByShadow super, @getShadow()
  getPendingBaseDrawArea: -> _expandRectangleByShadow super, @getPendingShadow()

  _prepareDrawOptions: (drawOptions, compositeMode, opacity)->
    super
    drawOptions.fillStyle     = @_gradient
    drawOptions.shadow        = @_shadow

    if @_gradient
      # I don't love this solution to scaling the gradient from/to, but it's acceptable for now.
      # It creates two new objects, which is unfortunate. It also mutates an object which should be immutable.
      @_gradient.from   = @_from.mul @_currentSize
      @_gradient.to     = @_to.mul @_currentSize
