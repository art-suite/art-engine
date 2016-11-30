Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'
Helper = require '../Helper'

{insepct, log, bound} = Foundation
{point, rect, Matrix, matrix} = Atomic
{RectangleElement, FillElement, BlurElement} = Engine
{drawTest, drawTest2, drawTest3} = Helper

suite "Art.Engine.Elements.Filters.BlurElement", ->
  drawTest2 "basic -", ->
    ao = new RectangleElement color:"red", size:point(80, 60),
      new FillElement
      new RectangleElement
        color: "yellow"
        size: ps: .5
        location: ps: .25
      new BlurElement radius:10

  drawTest2 "basic scale = 2", ->
    ao = new RectangleElement color:"red", size:point(40, 30), elementToParentMatrix:Matrix.scale(2),
      new FillElement
      new RectangleElement
        color: "yellow"
        size: ps: .5
        location: ps: .25
      new BlurElement radius:5

  drawTest2 "shape on top", ->
    new RectangleElement color:"red", size:point(80, 60),
      new FillElement
      new BlurElement radius:10
      new RectangleElement
        color: "yellow"
        size: ps: .5
        location: ps: .25

  drawTest2 "parent overdraw required - partially offscreen elements should look identical to fully onscreen element - should see red along the entire lefthand side", ->
    new RectangleElement
      color:"red"
      size:     point(80, 60)
      location: point(-30, 0)
      new FillElement
      new RectangleElement
        color: "yellow"
        size: ps: .5
        location: ps: .25
      new BlurElement radius:10
