Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
FilterElement = require './filter_element'
{createWithPostCreate} = Foundation
{color, Color, point, Point, rect, Rectangle, matrix, Matrix} = Atomic

module.exports = createWithPostCreate class ShadowElement extends FilterElement
  constructor: (options = {}) ->
    options.radius = 10 unless options.radius?
    options.compositeMode ||= "destover"
    @inverted = options.inverted
    super

  @drawProperty
    radius:   default: 0, validate: (v) -> typeof v is "number"

  filter: (elementSpaceTarget, scale) ->
    elementSpaceTarget.blurAlpha @_radius * scale, inverted:@inverted
    elementSpaceTarget.drawRectangle null, elementSpaceTarget.size, color:@_color, compositeMode:"target_alphamask"
