Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
Engine = require 'art-engine'
StateEpochTestHelper = require './StateEpochTestHelper'

{point, matrix, Matrix} = Atomic
{inspect, nextTick, eq, log, merge} = Foundation
{Element, CanvasElement} = Engine.Core

HtmlCanvas = Foundation.Browser.DomElementFactories.Canvas

{stateEpochTest} = StateEpochTestHelper

reducedRange = (data, factor = 32) ->
  parseInt (a + factor/2) / factor for a in data

module.exports = suite:
  preprocessEventHandlers: ->

    test "no preprocessEventHandlers", ->
      new Promise (resolve) ->
        e = new Element on: myEvent: resolve
        e.onNextReady -> e.queueEvent "myEvent"

    test "preprocessEventHandlers with no on-property", ->
      new Promise (resolve) ->
        class MyElement extends Element

          preprocessEventHandlers: (handlerMap) ->
            merge handlerMap,
              myEvent: resolve

        e = new MyElement
        e.onNextReady -> e.queueEvent "myEvent"

    test "preprocessEventHandlers with on-property", ->
      new Promise (resolve) ->
        class MyElement extends Element

          preprocessEventHandlers: (handlerMap) ->
            merge handlerMap,
              myEvent: resolve

        e = new MyElement on: myOtherEvent: -> e.queueEvent "myEvent"
        e.onNextReady -> e.queueEvent "myOtherEvent"

  family: ->
    # return false
    test "parentChanged - addChild", ->
      new Promise (resolve) ->
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
            resolve()
        # p.onNextReady =>
        p.addChild c

    test "parentChanged - children=", ->
      new Promise (resolve) ->
        new Element null,
          new Element on: parentChanged: resolve

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


  rootElementChanged: ->
    skipKnownFailingTest "basic", ->
      canvasElement = null
      new Promise (resolve) ->
        p = new Element name: "parent",
          c = new Element
            name: "child"
            on: rootElementChanged: ({target, props: {rootElement,oldRootElement}}) ->
              if rootElement == canvasElement
                resolve target:target, c:c, oldRootElement:oldRootElement, p:p

        p.onNextReady ->
          assert.eq c.rootElement, p
          canvasElement = new CanvasElement canvas: HtmlCanvas(), p

      .then ({c, target, oldRootElement, p}) ->
        knownFailingExplanation = """
          KNOWN FAILURE:

          The end-result is correct, but two events are
          fired when only one should be. The first event
          is incorrect.

          SBD: I just haven't looked closely at this yet.
          It should be solvable.
          """
        assert.eq c.canvasElement, canvasElement
        assert.eq target, c
        assert.eq oldRootElement, p, knownFailingExplanation

    stateEpochTest "handler added later", ->
      p = new Element
        name: "parent"
        c = new Element
          name: "child"

      canvasElement = new CanvasElement canvas: HtmlCanvas()

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

      canvasElement = new CanvasElement canvas: HtmlCanvas()
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
