Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'
Helper = require '../helper'

{drawAndTestElement} = require '../../test_helper'

{insepct, log} = Foundation
{point, Matrix, matrix} = Atomic
{RectangleElement, FillElement, OutlineElement} = Engine

{drawTest, drawTest2} = Helper

suite "Art.Engine.Elements.Shapes.RectangleElement", ->
  drawTest2 "basic", ->
    new RectangleElement color:"red", size: point 80, 60

  drawTest2 "add compositeMode", ->
    new RectangleElement compositeMode: "add", color: "red", size: point 80, 60

  drawTest2 "with opacity .5", ->
    new RectangleElement opacity: .5, color: "red", size: point 80, 60

suite "Art.Engine.Elements.Shapes.RectangleElement.children.basic", ->
  drawTest2 "children", ->
    new RectangleElement color: "red", size: point(80, 60), radius: 10,
      new FillElement

      new RectangleElement
        color:"#70F7",
        axis: point .5
        location: ps: .5
        size: 80
        angle: Math.PI * .3

suite "Art.Engine.Elements.Shapes.RectangleElement.children.mask", ->
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

suite "Art.Engine.Elements.Shapes.RectangleElement.children.clipping", ->
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

suite "Art.Engine.Elements.Shapes.RectangleElement.gradient colors", ->
  drawTest2 "gradient basic", ->
    new RectangleElement colors:["red", "yellow"], size:point 80, 60

  drawTest2 "gradient with gradientRadius", ->
    new RectangleElement
      colors:["red", "yellow"]
      from: "centerCenter"
      gradientRadius: 1
      size:point 80, 60

  drawTest2 "gradient with gradientRadius array", ->
    new RectangleElement
      colors:["black", "white", "black", "#777"]
      from: "centerCenter"
      gradientRadius: [.5, 1.5]
      size:point 80, 60

  drawTest2 "gradient with from and to", ->
    new RectangleElement colors:["red", "yellow"], from: "centerCenter", to: "topRight", size:point 80, 60

  drawTest2 "gradient with PointLayout from and tos", ->
    new RectangleElement
      colors: ["red", "yellow"]
      from: hh: 1
      to:   ww: 1
      size: point 80, 60

  drawTest2 "gradient with all options", ->
    new RectangleElement
      colors:["black", "white", "black", "#777"]
      from: .5
      to: 1/4
      gradientRadius: [.5, 2]
      size:point 80, 60

suite "Art.Engine.Elements.Shapes.RectangleElement.drawArea", ->
  drawAndTestElement "basic", ->
    element: new RectangleElement
      color: "#aaa"
      # shadow: color: "black", blur: 10, offsetY: 10

    test: (root) ->
      assert.eq root.drawArea.toArray(), [0, 0, 100, 100]

  drawAndTestElement "offset no blur", ->
    element: new RectangleElement
      color: "#aaa"
      shadow:
        color: "black"
        blur: 0
        offset: x: 5, y: 7

    test: (root) ->
      assert.eq root.drawArea.toArray(), [0, 0, 105, 107]

  drawAndTestElement "blur", ->
    element: new RectangleElement
      color: "#aaa"
      shadow:
        color: "black"
        blur: 10

    test: (root) ->
      assert.eq root.drawArea.toArray(), [-10, -10, 120, 120]

  drawAndTestElement "offset and blur", ->
    element: new RectangleElement
      color: "#aaa"
      shadow:
        color: "black"
        blur: 10
        offset: x: 5, y: 7

    test: (root) ->
      assert.eq root.drawArea.toArray(), [-10 + 5, -10 + 7, 120, 120]

  drawAndTestElement "FillElement shadow offset and blur", ->
    element: new RectangleElement
      color: "#aaa"
      new FillElement
        shadow:
          color: "black"
          blur: 10
          offset: x: 5, y: 7

    test: (root) ->
      assert.eq root.drawArea.toArray(), [-10 + 5, -10 + 7, 120, 120]


suite "Art.Engine.Elements.Shapes.RectangleElement.drawArea OutlineElement", ->
  drawAndTestElement "OutlineElement basic", ->
    element: new RectangleElement
      color: "#aaa"
      new OutlineElement
        lineWidth: 10

    test: (root) ->
      assert.eq root.drawArea.toArray(), [-50, -50, 200, 200]

  drawAndTestElement "OutlineElement lineJoin: bevel", ->
    element: new RectangleElement
      color: "#aaa"
      new OutlineElement
        lineWidth: 10
        lineJoin: "bevel"

    test: (root) ->
      assert.eq root.drawArea.toArray(), [-5, -5, 110, 110]

  drawAndTestElement "OutlineElement miterLimit: 3", ->
    element: new RectangleElement
      color: "#aaa"
      new OutlineElement
        lineWidth: 10
        miterLimit: 3

    test: (root) ->
      assert.eq root.drawArea.toArray(), [-15, -15, 130, 130]


  drawAndTestElement "OutlineElement shadow offset and blur", ->
    element: new RectangleElement
      color: "#aaa"
      new OutlineElement
        lineWidth: 10
        color: "orange"
        lineJoin: "bevel"
        shadow:
          color: "red"
          blur: 10
          offset: x: 5, y: 7

    test: (root) ->
      assert.eq root.drawArea.toArray(), [
        # outline, blur, offset
        -5         - 10  + 5
        -5         - 10  + 7
        110        + 20
        110        + 20
      ]
