Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
{Elements} = require 'art-engine'
Helper = require '../helper'
Canvas = require 'art-canvas'

{inspect, log} = Foundation
{point, rect, matrix, Matrix} = Atomic
{BitmapElement} = Elements

{drawTest, drawTest2} = Helper

source = new Canvas.Bitmap point 80, 60
source.clear "#f70"
source.drawRectangle point(5), point(70,50),  color:"#777"
source.drawRectangle point(10), point(60,40), color:"#f70"
source.drawRectangle point(15), point(50,30), color:"#777"
source.drawRectangle point(20), point(40,20), color:"#f70"
source.drawRectangle point(25), point(30,10), color:"#777"

suite "Art.Engine.Elements.Shapes.BitmapElement", ->
  drawTest2 "basic", ->
    new BitmapElement bitmap:source

  drawTest2 "shadow", ->
    new BitmapElement bitmap:source, shadow: offsetY:4, offsetX:4, blur:2, color: "#0005"

  drawTest2 "zoom", ->
    new BitmapElement bitmap:source, mode:"zoom", size:100

  drawTest2 "zoom with focus left", ->
    new BitmapElement bitmap:source, mode:"zoom", size:100, focus: point(0, .5)

  drawTest2 "zoom with focus right", ->
    new BitmapElement bitmap:source, mode:"zoom", size:100, focus: point(1, .5)

  drawTest2 "fit", ->
    new BitmapElement bitmap:source, mode:"fit", size:100

  drawTest2 "stretch", ->
    new BitmapElement bitmap:source, mode:"stretch", size:100

  drawTest2 "min large", ->
    new BitmapElement bitmap:source, mode:"min", size:100

  drawTest2 "min small", ->
    new BitmapElement bitmap:source, mode:"min", size:50

  drawTest2 "sourceArea basic", ->
    new BitmapElement bitmap:source, sourceArea:rect(10,10,60,40)

  drawTest2 "sourceArea zoom", ->
    new BitmapElement bitmap:source, sourceArea:rect(10,10,60,40), mode:"zoom", size:100

  drawTest2 "sourceArea fit", ->
    new BitmapElement bitmap:source, sourceArea:rect(10,10,60,40), mode:"fit", size:100

  drawTest2 "sourceArea stretch", ->
    new BitmapElement bitmap:source, sourceArea:rect(10,10,60,40), mode:"stretch", size:100

  drawTest2 "sourceArea min large", ->
    new BitmapElement bitmap:source, sourceArea:rect(10,10,60,40), mode:"min", size:100

  drawTest2 "sourceArea min small", ->
    new BitmapElement bitmap:source, sourceArea:rect(10,10,60,40), mode:"min", size:30
