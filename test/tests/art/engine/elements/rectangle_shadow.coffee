define [
  'extlib/chai'
  'lib/art/foundation'
  'lib/art/atomic'
  'lib/art/engine'
  './helper'
], (chai, Foundation, Atomic, Engine, Helper) ->
  assert = chai.assert
  {insepct, log} = Foundation
  {point, rect, Matrix, matrix} = Atomic
  {Elements} = Engine
  {Rectangle, RectangleShadow, Shapes} = Elements
  {drawTest, drawTest2, drawTest3} = Helper

  suite "Art.Engine.Elements.RectangleShadow", ->
    drawTest2 "basic radius 0", ->
      new RectangleShadow size:point 80, 60

    drawTest2 "basic radius 10", ->
      new RectangleShadow radius:10, size:point 80, 60

    drawTest2 "basic radius 16", ->
      new RectangleShadow radius:16, size:point 80, 60

    drawTest2 "basic radius 24", ->
      new RectangleShadow radius:24, size:point 80, 60

    drawTest2 "basic radius 32", ->
      new RectangleShadow radius:32, size:point 80, 60

    drawTest2 "with opacity .5", ->
      new RectangleShadow radius: 5, opacity:.5, size:point 80, 60
