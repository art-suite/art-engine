define [
  'extlib/chai'
  'lib/art/foundation'
  'lib/art/atomic'
  'lib/art/engine/elements'
  './helper'
], (chai, Foundation, Atomic, Elements, Helper) ->
  assert = chai.assert
  {insepct, log} = Foundation
  {point, Matrix, matrix} = Atomic
  {Rectangle, Fill} = Elements

  {drawTest, drawTest2} = Helper

  suite "Art.Engine.Elements.Shapes.Rectangle", ->
    drawTest2 "basic", ->
      new Rectangle color:"red", size:point 80, 60

    drawTest2 "add compositeMode", ->
      new Rectangle compositeMode:"add", color:"red", size:point 80, 60

    drawTest2 "with opacity .5", ->
      new Rectangle opacity:.5, color:"red", size:point 80, 60

    drawTest2 "children", ->
      new Rectangle color:"red", size:point(80, 60), radius:10,
        new Fill

        new Rectangle
          color:"#70F7",
          axis: point .5
          location: ps: .5
          size: 80
          angle: Math.PI * .3

    drawTest2 "children with mask, radius:0", ->
      new Rectangle
        color:"red"
        size: point(80, 60)
        angle: .1
        new Rectangle
          color:"#F0F"
          axis: point .5
          location: ps: .5
          size: 80
          angle: Math.PI * .3
        new Fill isMask:true

    drawTest2 "children with mask, radius:20", ->
      new Rectangle
        color:"red"
        # clip: true
        size: point(80, 60)
        angle: .1
        radius: 20
        new Rectangle
          color:"#F0F"
          axis: point .5
          location: ps: .5
          size: 80
          angle: Math.PI * .3
        new Fill isMask:true

    drawTest2 "children with clipping, radius:0", ->
      new Rectangle
        color:"red"
        clip: true
        size: point(80, 60)
        angle: .1
        new Rectangle
          color:"#F0F"
          axis: point .5
          location: ps: .5
          size: 80
          angle: Math.PI * .3

    drawTest2 "children with clipping, radius:20", ->
      new Rectangle
        color:"red"
        clip: true
        size: point(80, 60)
        angle: .1
        radius: 20
        new Rectangle
          color:"#F0F"
          axis: point .5
          location: ps: .5
          size: 80
          angle: Math.PI * .3
