define [

  'art.foundation'
  'art.atomic'
  'art.engine'
  './helper'
], (Foundation, Atomic, {Elements}, Helper) ->

  {insepct, log, bound} = Foundation
  {point, rect, Matrix, matrix} = Atomic
  {Filter, Rectangle, Fill, Blur} = Elements
  {drawTest, drawTest2, drawTest3} = Helper

  suite "Art.Engine.Elements.Filters.Blur", ->
    drawTest2 "basic -", ->
      ao = new Rectangle color:"red", size:point(80, 60),
        new Fill
        new Rectangle
          color: "yellow"
          size: ps: .5
          location: ps: .25
        new Blur radius:10

    drawTest2 "basic scale = 2", ->
      ao = new Rectangle color:"red", size:point(40, 30), elementToParentMatrix:Matrix.scale(2),
        new Fill
        new Rectangle
          color: "yellow"
          size: ps: .5
          location: ps: .25
        new Blur radius:5

    drawTest2 "shape on top", ->
      new Rectangle color:"red", size:point(80, 60),
        new Fill
        new Blur radius:10
        new Rectangle
          color: "yellow"
          size: ps: .5
          location: ps: .25

    drawTest2 "parent overdraw required - partially offscreen elements should look identical to fully onscreen element - should see red along the entire lefthand side", ->
      new Rectangle
        color:"red"
        size:     point(80, 60)
        location: point(-30, 0)
        new Fill
        new Rectangle
          color: "yellow"
          size: ps: .5
          location: ps: .25
        new Blur radius:10
