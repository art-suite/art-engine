Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
FilterElement = require './filter_element'
{createWithPostCreate} = Foundation
{color, Color, point, Point, rect, Rectangle, matrix, Matrix} = Atomic

module.exports = createWithPostCreate class ShadowElement extends FilterElement
  defaultCompositeMode: "destover"

  @drawProperty
    inverted: default: false

  filter: (elementSpaceTarget, scale) ->
    elementSpaceTarget.blurAlpha @_radius * scale, inverted: @inverted
    elementSpaceTarget.drawRectangle null, elementSpaceTarget.size, color:@_color, compositeMode:"target_alphamask"
