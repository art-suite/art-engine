define [
  'art-foundation'
  'art-atomic'
  './filter'
], (Foundation, Atomic, Filter) ->
  {createWithPostCreate} = Foundation
  {color, Color, point, Point, rect, Rectangle, matrix, Matrix} = Atomic

  createWithPostCreate class Blur extends Filter
    defaultRadius: 10
    defaultCompositeMode: "replace"

    filter: (elementSpaceTarget, scale) ->
      elementSpaceTarget.blur @radius * scale
