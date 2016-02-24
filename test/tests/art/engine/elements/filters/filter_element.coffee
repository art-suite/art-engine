Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
{Elements} = require 'art-engine'
Helper = require '../helper'

{insepct, log, bound} = Foundation
{point, rect, Matrix, matrix} = Atomic
{FilterElement, RectangleElement, FillElement} = Elements
{drawTest, drawTest2, drawTest3} = Helper

class InvertFilter extends FilterElement
  filterPixelData: (elementSpaceTarget, pixelData) ->
    for r, i in pixelData by 4
      g = pixelData[i+1]
      b = pixelData[i+2]
      pixelData[i  ] = 255 - r
      pixelData[i+1] = 255 - g
      pixelData[i+2] = 255 - b
    pixelData

class WaveFilter extends FilterElement

  copy: (data1, x1, y1, data2, x2, y2, xStep, yStep) ->
    l1 = y1 * yStep + x1 * xStep
    l2 = y2 * yStep + x2 * xStep

    data2[l2 + 0] = data1[l1 + 0]
    data2[l2 + 1] = data1[l1 + 1]
    data2[l2 + 2] = data1[l1 + 2]
    data2[l2 + 3] = data1[l1 + 3]

  filterPixelData: (elementSpaceTarget, src, scale) ->
    dstBuffer = src.buffer.slice()
    dst = src
    src = new src.constructor dstBuffer
    # src = tmp
    {w, h} = elementSpaceTarget.size

    yStep = w * 4
    xStep = 4
    r = @radius | 0
    r = 2 if r < 2

    amplitude = scale * @radius
    frequency = 5 * (Math.PI * 2) / h
    for y in [0..h-1] by 1
      offset = amplitude * Math.sin(frequency * y) | 0
      for x in [0..w-1] by 1
        x1 = bound 0, x + offset, w - 1
        # x1 = 0 if x1 < 0
        # x1 = w - 1 if x1 >= w
        @copy src, x1, y, dst, x, y, xStep, yStep

suite "Art.Engine.Elements.Filters.FilterElement", ->
  drawTest2 "basic invert", ->
    ao = new RectangleElement color:"red", location:50,
      new FillElement
      new RectangleElement color:"orange", location: {ps:.2}, size: ps:.4
      new RectangleElement color:"yellow", location: {ps:.4}, size: ps:.4
      new InvertFilter location: 30

  drawTest2 "basic invert draw with scale == 2", ->
    ao = new RectangleElement color:"red", location:25, elementToParentMatrix: Matrix.scale(2),
      new FillElement
      new RectangleElement color:"orange", location: {ps:.2}, size: ps:.4
      new RectangleElement color:"yellow", location: {ps:.4}, size: ps:.4
      new InvertFilter location: 15

  drawTest2 "basic wave", ->
    ao = new RectangleElement color:"red", location:50,
      new FillElement
      new RectangleElement color:"orange", location: {ps:.2}, size: ps:.4
      new RectangleElement color:"yellow", location: {ps:.4}, size: ps:.4
      new WaveFilter radius:10

  drawTest2 "basic wave draw with scale == 2", ->
    ao = new RectangleElement color:"red", location:25, elementToParentMatrix: Matrix.scale(2),
      new FillElement
      new RectangleElement color:"orange", location: {ps:.2}, size: ps:.4
      new RectangleElement color:"yellow", location: {ps:.4}, size: ps:.4
      new WaveFilter radius:5

  drawTest2 "parentSourceArea", ->
    ao = new RectangleElement color:"red", location:50,
      new FillElement
      new RectangleElement color:"orange", location: {ps:.2}, size: ps:.4
      new RectangleElement color:"yellow", location: {ps:.4}, size: ps:.4
      new InvertFilter parentSourceArea: rect(10,0,30,40), opacity:.66

  drawTest2 "basic, rotated", ->
    ao = new RectangleElement color:"#0ff", location:50,
      new FillElement
      new RectangleElement color:"#70f", location: {ps:.2}, size: ps:.4
      new RectangleElement color:"#f0f", location: {ps:.4}, size: ps:.4
      new InvertFilter axis:.5, angle:1, opacity:.9, location: ps: .5

  drawTest2 "parent overdraw required - partially offscreen elements should look identical to fully onscreen element - should see red along the entire lefthand side", ->
    new RectangleElement
      color:"red"
      location:point(80, 60)
      location: point(-30, 0)
      new FillElement
      new RectangleElement color:"yellow", location: {ps:.25}, size: ps:.5
      new WaveFilter opacity:.75, radius:10

  drawTest2 "parent overdraw required - control", ->
    new RectangleElement
      color:"red"
      location:point(80, 60)
      new FillElement
      new RectangleElement color:"yellow", location: {ps:.25}, size: ps:.5
      new WaveFilter opacity:.75, radius:10
