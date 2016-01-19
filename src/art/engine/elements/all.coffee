define [
  'art-foundation'
  '../core'
  './namespace'
  './shapes'
  './filters'
  './scroll_element'
], ({createAllClass}, Core, Elements, Shapes, Filters, ScrollElement) ->

  createAllClass Elements,
    Shapes
    Filters
    Element:        Core.Element
    CanvasElement:  Core.CanvasElement
    ScrollElement:  ScrollElement
