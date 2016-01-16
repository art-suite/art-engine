define [

  'art.foundation'
  'art.atomic'
  'art.engine'
  './helper'
], (Foundation, Atomic, {Elements}, Helper) ->

  {insepct, log} = Foundation
  {point, rect, Matrix, matrix} = Atomic
  {Fill, Shadow, Rectangle, Outline, Element, TextElement} = Elements
  {drawTest, drawTest2, drawTest3} = Helper

  suite "Art.Engine.Elements.Filters.Shadow", ->
    drawTest3 "basic",
      stagingBitmapsCreateShouldBe: 1
      element: ->
        new Rectangle color:"red", size:point(80, 60),
          new Fill
          new Shadow radius: 10, location: 10

    drawTest3 "shadow shadow",
      stagingBitmapsCreateShouldBe: 1
      elementSpaceDrawAreaShouldBe: rect 0, 0, 110, 90
      element: ->
        new Rectangle color: "red", size: point(80, 60),
          new Fill
          new Shadow radius: 0, color: "orange", location: 10
          new Shadow
            size: ps:1, w:10, h:10
            location: 10
            parentSourceArea: point 90, 70
            radius: 10

    drawTest3 "outline shadow",
      stagingBitmapsCreateShouldBe: 1
      elementSpaceDrawAreaShouldBe: rect -5, -5, 110, 90
      element: ->
        new Rectangle color:"red", size:point(80, 60),
          new Fill
          new Outline
            color: "orange"
            lineWidth: 10
            lineJoin: "round"
            compositeMode: "destover"
          new Shadow
            radius:10
            parentSourceArea: rect -5, -5, 90, 70
            location: 5
            size: w:90, h:70


    drawTest2 "parent overdraw required", ->
      new Rectangle color:"red", size:point(80, 60), location: point(-100, -20),
        new Fill
        new Shadow radius:10, location:point 10

    drawTest2 "gradient child filterSource", ->
      new Rectangle
        color:          "red"
        size:           point(80, 60)
        radius:         50
        name:           "myFilterSource"
        new Fill
        new Element
          location: 10
          compositeMode: "destover"
          new Rectangle
            size: plus:20, ps:1
            location: -10
            colors: [
              "#f0f", "#ff0"
              "#f0f", "#ff0"
              "#f0f", "#ff0"
              "#f0f", "#ff0"
              "#f0f", "#ff0"
            ]
          new Shadow
            radius: 4
            isMask: true
            filterSource: "myFilterSource"

    drawTest3 "opacity 50%",
      element: ->
        new Rectangle color:"red", size:point(80, 60),
          new Fill
          new Shadow radius:10, opacity:.5, location:point 10

    drawTest2 "sourcein", ->
      new Rectangle color:"red", size:point(80, 60),
        new Fill
        new Shadow radius:10, compositeMode:"sourcein", location:point 10

    drawTest2 "inverted shadow", ->
      new Rectangle color:"red", size:point(80, 60),
        new Fill
        new Shadow inverted:true, radius:10, compositeMode:"sourcein", location:point 10

    drawTest2 "with 50% scaled drawMatrix", ->
      new Rectangle color:"red", size:point(80, 60), scale:point(.5),
        new Fill
        new Shadow radius:10, location:point 10

    drawTest2 "parent rotated 180deg - shadow should be to the upper-left", ->
      new Rectangle color:"red", size:point(80, 60), axis:.5, location:point(50,30), angle:Math.PI,
        new Fill
        new Shadow radius:10, location:point 10

    drawTest2 "parent rotated 45deg - shadow should offset directly down", ->
      new Rectangle color:"red", size:point(80, 60), axis:.5, location:point(50,30), angle:Math.PI/4,
        new Fill
        new Shadow radius:10, location:point 10

    drawTest2 "shadow rotated 60deg", ->
      new Rectangle color:"red", size:point(80, 60),
        new Fill
        new Shadow radius:10, axis:.5, angle:Math.PI/3, location: wpw:.5, hph:.5, x:10, y:10

    drawTest3 "child of TextElement basic",
      stagingBitmapsCreateShouldBe: 1
      element: ->
        new TextElement fontFamily:"impact", fontSize:80, text:"TextElement",
          new Fill color: "red"
          new Shadow radius:10, location:10

    drawTest3 "child of TextElement gradient",
      stagingBitmapsCreateShouldBe: 3
      element: ->
        new TextElement
          fontFamily:     "impact"
          fontSize:       80
          text:           "TextElement"
          name: "myTextElement"
          new Fill color: "red"
          new Element
            location:10
            compositeMode: "destover"
            new Rectangle
              size: ps:1, plus:20
              location: -10
              colors: [
                "#f0f", "#ff0"
                "#f0f", "#ff0"
                "#f0f", "#ff0"
                "#f0f", "#ff0"
                "#f0f", "#ff0"
              ]
            new Shadow radius:10, isMask:true, filterSource:"myTextElement"

