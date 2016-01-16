define [

  'art.foundation'
  'art.atomic'
  'art.canvas'
  'art.engine'
  './state_epoch_test_helper'
], (Foundation, Atomic, Canvas, {Core:EngineCore}, StateEpochTestHelper) ->

  {point, matrix, Matrix} = Atomic
  {inspect, nextTick, eq, log} = Foundation
  {Element, CanvasElement} = EngineCore

  {stateEpochTest} = StateEpochTestHelper

  reducedRange = (data, factor = 32) ->
    parseInt (a + factor/2) / factor for a in data

  suite "Art.Engine.Core.Element", ->
    suite "family events", ->
      # return false
      test "parentChanged - addChild", (done)->
        p = new Element
          name: "parent"
        window.c =
        c = new Element
          name: "child"
          on: parentChanged: (e)=>
            assert.eq c.parent, p
            assert.eq e.target, c
            assert.eq e.parent, p
            assert.eq e.oldParent, null
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
          c.on = parentChanged: (e)->
            assert.eq c.parent, null
            assert.eq p.children, []
            assert.eq e.target, c
            assert.eq e.oldParent, p
            assert.eq e.parent, null
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


      suite "rootElementChanged", ->
        test "basic", (done)->
          p = new Element name: "parent",
            c = new Element
              name: "child"
              on: rootElementChanged: (e) ->
                if e.rootElement == canvasElement
                  assert.eq c.canvasElement, canvasElement
                  assert.eq e.target, c
                  assert.eq e.oldRootElement, p
                  done()

          canvasElement = null
          p.onNextReady ->
            canvasElement = new CanvasElement
            canvasElement.addChild p

        stateEpochTest "handler added later", ->
          p = new Element
            name: "parent"
            c = new Element
              name: "child"

          canvasElement = new CanvasElement

          (done) ->
            log "add rootElementChanged, add child p"
            c.on = rootElementChanged: (e) =>
              assert.eq e.rootElement, canvasElement
              assert.eq c.canvasElement, canvasElement
              assert.eq e.target, c
              assert.eq e.oldRootElement, p
              done()

            canvasElement.addChild p

        stateEpochTest "orphaned", ->
          p = new Element
          c = new Element

          canvasElement = new CanvasElement
          p.addChild c
          canvasElement.addChild p

          (done) ->
            c.on = rootElementChanged: (e) =>
              assert.eq e.rootElement, p
              assert.eq c.canvasElement, null
              assert.eq e.target, c
              assert.eq e.oldRootElement, canvasElement
              done()

            p.removeFromParent()

        test "on construction, oldRootElement is null", (done)->
          p = new Element null,
            c = new Element
              on: rootElementChanged: (e) =>
                assert.eq e.rootElement, p
                assert.eq c.canvasElement, null
                assert.eq e.target, c
                assert.eq e.oldRootElement, c
                done()

        stateEpochTest "after construction, oldRootElement is set to this", ->
          p = new Element
          c = new Element

          (done)->
            c.on = rootElementChanged: (e) =>
                assert.eq e.rootElement, p
                assert.eq c.canvasElement, null
                assert.eq e.target, c
                assert.eq e.oldRootElement, c
                done()

            p.addChild c
