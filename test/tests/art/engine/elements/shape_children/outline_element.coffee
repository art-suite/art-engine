Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'
Helper = require '../helper'

{inspect, log} = Foundation
{point, rect, matrix, Matrix, rgbColor} = Atomic
{OutlineElement, RectangleElement, TextElement, FillElement} = Engine

{drawTest, drawTest2, drawTest3} =  Helper

suite "Art.Engine.Elements.ShapeChildren.OutlineElement", ->
  drawTest3 "lineWidth and lineJoin",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      new RectangleElement size: point(50,50),
        new FillElement color:"#ff0"
        new OutlineElement
          color:"#f0f"
          lineWidth:20
          lineJoin: "bevel"

  drawTest3 "lineJoin round",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      new RectangleElement size: point(50,50),
        new FillElement color:"#ff0"
        new OutlineElement
          color:"#f0f"
          lineWidth:20
          lineJoin: "round"

  drawTest3 "two lines",
    stagingBitmapsCreateShouldBe: 0
    element: ->

      new RectangleElement size: point(50,50),
        new FillElement color:"#ff0"

        new OutlineElement
          color:"#f0f"
          lineWidth:20
          lineJoin: "round"

        new OutlineElement
          color:"#ff0"
          lineWidth:10
          lineJoin: "round"

  drawTest3 "half width",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      new RectangleElement size: point(50,50),
        new FillElement color:"#ff0"
        new OutlineElement
          color:"#f0f"
          lineWidth:20
          lineJoin: "round"
          size: wpw:.5, hph:1

  drawTest3 "rotated",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      new RectangleElement size: point(50,50),
        new FillElement color:"#ff0"
        new OutlineElement
          color: rgbColor 1, 0, 1, .25
          lineWidth:20
          axis: point .5
          location: ps:.5
          angle: Math.PI/8
          lineJoin: "round"

  drawTest3 "child of rectangle",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      new RectangleElement size: point(50,50),
        new FillElement color:"#ff0"
        new OutlineElement color:rgbColor(1,0,1,.5), lineWidth:10

  drawTest3 "child of TextElement basic",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      parent = new TextElement fontFamily:"impact", fontSize:80, text:"TextElement",
        new FillElement color: "red"
        new OutlineElement color:rgbColor(0,1,0,.5), lineWidth:10

  drawTest3 "child of TextElement with offset",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      parent = new TextElement fontFamily:"impact", fontSize:80, text:"TextElement",
        new FillElement color: "red"
        new OutlineElement filled:true, color: rgbColor(0,0,0,.75), lineWidth:0, location:-28, opacity: .99

  drawTest3 "child of TextElement filled",
    stagingBitmapsCreateShouldBe: 0
    element: ->
      parent = new TextElement fontFamily:"impact", fontSize:80, text:"TextElement",
        new FillElement color: "red"
        new OutlineElement color: rgbColor(0,1,0,1), opacity:.25, lineWidth:10, filled:true

  drawTest3 "gradient child",
    stagingBitmapsCreateShouldBe: 0
    elementSpaceDrawAreaShouldBe: rect -10, -10, 70, 70
    element: ->
      new RectangleElement
        size: 50
        new FillElement color: "#ff0"

        new OutlineElement
          color:"#f0f"
          lineWidth:20
          lineJoin: "round"

          new FillElement
            colors: [
              "#f0f", "#ff0"
              "#f0f", "#ff0"
              "#f0f", "#ff0"
              "#f0f", "#ff0"
              "#f0f", "#ff0"
            ]
            to: "bottomRight"
