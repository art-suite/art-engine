Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'
StateEpochTestHelper = require '../state_epoch_test_helper'

{inspect, log, isArray, min, max} = Foundation
{point, matrix} = Atomic
{stateEpochTest} = StateEpochTestHelper

{Element, RectangleElement} = Engine

drawAndTestElement = (name, optionsF) ->
  test name, ->
    options = optionsF()
    options.element.toBitmap()
    .then ({bitmap}) ->
      log bitmap, "test: #{name}"
      options.test()

suite "Art.Engine.Core.layout.scale", ->
  drawAndTestElement "fit", ->
    element: p = new Element
      size: 100
      clip: true
      new RectangleElement color:"yellow"
      c = new Element
        size: w: 1000, h: 750
        axis: .5
        location: "centerCenter"
        scale: (parentSize, childSize) ->
          parentSize.div(childSize).min()
        new RectangleElement color:"red"
        new RectangleElement
          size: (ps) -> ps.min()
          axis: .5
          location: "centerCenter"
          color: "white"
          radius: 10000

    test: ->
      assert.eq c.currentScale, point 0.1


  drawAndTestElement "zoom", ->
    element: p = new Element
      size: 100
      clip: true
      new RectangleElement color:"yellow"
      c = new Element
        size: w: 1000, h: 750
        axis: .5
        location: "centerCenter"
        scale: (parentSize, childSize) ->
          parentSize.div(childSize).max()
        new RectangleElement color:"red"
        new RectangleElement
          size: (ps) -> ps.min()
          axis: .5
          location: "centerCenter"
          color: "white"
          radius: 10000

    test: ->
      assert.eq c.currentScale, point 100/750

  drawAndTestElement "wrapper element around dynamically scaled child", ->
    element: p = new Element
      size: 100
      clip: true
      new RectangleElement color:"yellow"
      c = new Element
        size:
          # set size to children's size, after the child is scaled
          cs: 1
          ###
          BUT, in order for layout to work, we need to limit the max size to parent's size
          Why?
            If this element's size is solely child-size relative, then we have a
            circular dependency:
              this element depends on childs size
              child element's scale (and consequently size) depends on parent's size
            In this case, when the child's scale gets computed, parent's size hasn't
            been resolved (due to the circular dependency) and is therefor assumed to
            be infinite.
          How does this work?
            This resolves the circular dependency by setting this element's size
            in the BEFORE CHILDREN LAYOUT to the minimum of inifinity and its parent's size.
            Therefor when, when the child does it's scale function, it effectively gets
            it's grandeparent's size as the parent-size input.
            Then, AFTER CHILDREN LAYOUT completes, this element sets its final size.
          ###
          max: ps: 1
        axis: .5
        location: "centerCenter"
        gc = new Element
          size: w: 1000, h: 750
          scale: (parentSize, childSize) ->
            parentSize.div(childSize).min()
          new RectangleElement color:"red"
          new RectangleElement
            size: (ps) -> ps.min()
            axis: .5
            location: "centerCenter"
            color: "white"
            radius: 10000

    test: ->
      assert.eq gc.currentScale, point 0.1
      assert.eq c.currentSize, point 100, 75
      gc.size = w: 1000, h: 2000

      gc.onNextReady()
      .then ->
        assert.eq gc.currentScale, point 0.05
        assert.eq c.currentSize, point 50, 100
