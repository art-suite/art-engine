Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
Engine = require 'art-engine'
StateEpochTestHelper = require './state_epoch_test_helper'

{point, matrix, Matrix} = Atomic
{inspect, nextTick, eq, log} = Foundation
{Element, CanvasElement} = Engine.Core

{stateEpochTest} = StateEpochTestHelper

reducedRange = (data, factor = 32) ->
  parseInt (a + factor/2) / factor for a in data

suite "Art.Engine.Core.Element.family events", ->
  # return false
  test "parentChanged - addChild", (done)->
    p = new Element
      name: "parent"
    window.c =
    c = new Element
      name: "child"
      on: parentChanged: ({target, props:{parent, oldParent}})=>
        assert.eq c.parent, p
        assert.eq target, c
        assert.eq parent, p
        assert.eq oldParent, null
        done()
    # p.onNextReady =>
    p.addChild c

  test "parentChanged - children=", (done)->
    new Element null,
      new Element on: parentChanged: => done()

  stateEpochTest "parentChanged - orphaned (a)", ->
    p = new Element null,
      c = new Element
    (done) ->
      c.on = parentChanged: ({target, props: {parent, oldParent}})->
        assert.eq c.parent, null
        assert.eq p.children, []
        assert.eq target, c
        assert.eq oldParent, p
        assert.eq parent, null
        done()
      c.removeFromParent()

  stateEpochTest "parentChanged - orphaned with children=", ->
    p = new Element null,
      c = new Element

    (done) ->
      c.on = parentChanged: (e)=>
        assert.eq c.parent, null
        done()

      p.children = []


suite "Art.Engine.Core.Element.family events.rootElementChanged", ->
  test "basic", ->
    canvasElement = null
    new Promise (resolve) ->
      p = new Element name: "parent",
        c = new Element
          name: "child"
          on: rootElementChanged: ({target, props:{rootElement,oldRootElement}}) ->
            if rootElement == canvasElement
              resolve target:target, c:c, oldRootElement:oldRootElement, p:p

      p.onNextReady ->
        assert.eq c.rootElement, p
        canvasElement = new CanvasElement {}, p

    .then ({c, target, oldRootElement, p}) ->
      assert.eq c.canvasElement, canvasElement
      assert.eq target, c
      assert.eq oldRootElement, p, "oldRootElement should be 'parent', which a previous assertion checked - it was set to parent at the begining. The rootElementChanged event is geting fired twice when it should only fire once. The end result is basically correct."

  stateEpochTest "handler added later", ->
    p = new Element
      name: "parent"
      c = new Element
        name: "child"

    canvasElement = new CanvasElement

    (done) ->
      log "add rootElementChanged, add child p"
      c.on = rootElementChanged: ({target, props:{rootElement, oldRootElement}}) =>
        assert.eq rootElement, canvasElement
        assert.eq c.canvasElement, canvasElement
        assert.eq target, c
        assert.eq oldRootElement, p
        done()

      canvasElement.addChild p

  stateEpochTest "orphaned", ->
    p = new Element
    c = new Element

    canvasElement = new CanvasElement
    p.addChild c
    canvasElement.addChild p

    (done) ->
      c.on = rootElementChanged: ({target, props:{rootElement, oldRootElement}}) =>
        assert.eq rootElement, p
        assert.eq c.canvasElement, null
        assert.eq target, c
        assert.eq oldRootElement, canvasElement
        done()

      p.removeFromParent()

  test "on construction, oldRootElement is null", (done)->
    p = new Element null,
      c = new Element
        on: rootElementChanged: (e) =>
          assert.eq e.props.rootElement, p
          assert.eq c.canvasElement, null
          assert.eq e.target, c
          assert.eq e.props.oldRootElement, c
          done()

  stateEpochTest "after construction, oldRootElement is set to this", ->
    p = new Element
    c = new Element

    (done)->
      c.on = rootElementChanged: (e) =>
          assert.eq e.props.rootElement, p
          assert.eq c.canvasElement, null
          assert.eq e.target, c
          assert.eq e.props.oldRootElement, c
          done()

      p.addChild c
