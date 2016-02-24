Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
{Elements} = require 'art-engine'
Helper = require '../helper'

{insepct, log} = Foundation
{point, Matrix, matrix} = Atomic
{RectangleElement, FillElement} = Elements

{drawTest, drawTest2} = Helper

suite "Art.Engine.Elements.Shapes.RectangleElement", ->
  drawTest2 "basic", ->
    new RectangleElement color:"red", size:point 80, 60

  drawTest2 "add compositeMode", ->
    new RectangleElement compositeMode:"add", color:"red", size:point 80, 60

  drawTest2 "with opacity .5", ->
    new RectangleElement opacity:.5, color:"red", size:point 80, 60

  drawTest2 "children", ->
    new RectangleElement color:"red", size:point(80, 60), radius:10,
      new FillElement

      new RectangleElement
        color:"#70F7",
        axis: point .5
        location: ps: .5
        size: 80
        angle: Math.PI * .3

  drawTest2 "children with mask, radius:0", ->
    new RectangleElement
      color:"red"
      size: point(80, 60)
      angle: .1
      new RectangleElement
        color:"#F0F"
        axis: point .5
        location: ps: .5
        size: 80
        angle: Math.PI * .3
      new FillElement isMask:true

  drawTest2 "children with mask, radius:20", ->
    new RectangleElement
      color:"red"
      # clip: true
      size: point(80, 60)
      angle: .1
      radius: 20
      new RectangleElement
        color:"#F0F"
        axis: point .5
        location: ps: .5
        size: 80
        angle: Math.PI * .3
      new FillElement isMask:true

  drawTest2 "children with clipping, radius:0", ->
    new RectangleElement
      color:"red"
      clip: true
      size: point(80, 60)
      angle: .1
      new RectangleElement
        color:"#F0F"
        axis: point .5
        location: ps: .5
        size: 80
        angle: Math.PI * .3

  drawTest2 "children with clipping, radius:20", ->
    new RectangleElement
      color:"red"
      clip: true
      size: point(80, 60)
      angle: .1
      radius: 20
      new RectangleElement
        color:"#F0F"
        axis: point .5
        location: ps: .5
        size: 80
        angle: Math.PI * .3
