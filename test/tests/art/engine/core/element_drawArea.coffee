define [
  'art-foundation'
  'art-atomic'
  'art-engine'
  './state_epoch_test_helper'
], (Foundation, Atomic, Engine, StateEpochTestHelper) ->

  {inspect, log, isArray} = Foundation
  {point, matrix, rect, Matrix} = Atomic
  {Element} = Engine.Core
  {OutlineElement, RectangleElement} = Engine
  {stateEpochTest} = StateEpochTestHelper

  suite "Art.Engine.Core.Element", ->
    suite "drawArea", ->
      stateEpochTest "basic parentSpaceDrawArea", ->
        o = new Element size:400
        ->
          assert.eq o.elementSpaceDrawArea, rect 0, 0, 400, 400
          assert.eq o.parentSpaceDrawArea,  rect 0, 0, 400, 400

      stateEpochTest "default elementSpaceDrawArea", ->
        o = new Element
        ->
          assert.eq o.elementSpaceDrawArea, rect 0, 0, 100, 100

      stateEpochTest "with no mask and children", ->
        o = new Element location:point(50,60), size: 400,
          new Element location:point(100,200), size: 400
        ->
          assert.eq o.elementSpaceDrawArea, rect 100, 200, 400, 400
          assert.eq o.parentSpaceDrawArea,  rect 150, 260, 400, 400

      stateEpochTest "child moves", ->
        p = new Element
          size:400
          c = new Element size:23, location:45
        ->
          assert.eq p.elementSpaceDrawArea, rect 45, 45, 23, 23
          c.location = 67
          ->
            assert.eq p.elementSpaceDrawArea, rect 67, 67, 23, 23

      stateEpochTest "child added", ->
        p = new Element
          size:400
          c = new Element size: 23, location: 45
        ->
          assert.eq p.elementSpaceDrawArea, rect 45, 45, 23, 23
          p.addChild new Element size:78, location: 89
          ->
            assert.eq p.elementSpaceDrawArea, rect 45, 45, 122, 122

      stateEpochTest "child removed", ->
        p = new Element
          size:400
          new Element size: 23, location: 45
          c = new Element size: 78, location: 89
        ->
          assert.eq p.elementSpaceDrawArea, rect 45, 45, 122, 122
          c.parent = null
          ->
            assert.eq p.elementSpaceDrawArea, rect 45, 45, 23, 23

      stateEpochTest "grandchild effects grandparent", ->
        gp = new Element {},
          p = new Element {},
            c = new Element size:23, location:45
        ->
          assert.eq gp.elementSpaceDrawArea, rect 45, 45, 23, 23
          c.location = 12
          ->
            assert.eq gp.elementSpaceDrawArea, rect 12, 12, 23, 23

      stateEpochTest "with mask and children outside mask", ->
        o = new Element location:point(50,60), size: 400,
          new Element location:point(100,200), size: 400
          new Element isMask:true

        ->
          assert.eq o.elementSpaceDrawArea, rect 100, 200, 300, 200
          assert.eq o.parentSpaceDrawArea,  rect 150, 260, 300, 200

      stateEpochTest "with some masked and some unmasked children", ->
        o = new Element location:point(50,60), size: 400,
          new Element location:point(100,200), size: 400
          new Element compositeMode:"alphaMask"
          new Element location:point(-100,-200), size: 40

        ->
          assert.eq o.parentSpaceDrawArea, rect 50-100, 60-200, 500, 600

      stateEpochTest "with intersting transformation matrix", ->
        o = new Element size: 400
        ->
          m = Matrix.rotate Math.PI/4
          assert.eq o.drawAreaIn(m).roundOut(), rect -283, 0, 566, 566

      stateEpochTest "with outline", ->
        o = new RectangleElement color:"#ff0", size: 50,
          outline = new OutlineElement
            lineWidth:20
            lineJoin: "round"

        ->
          assert.eq o.elementSpaceDrawArea, rect -10, -10, 70, 70
