define [
  'art.foundation'
  'art.atomic'
  'art.engine'
  './state_epoch_test_helper'
], (Foundation, Atomic, {Core:EngineCore, Layout}, StateEpochTestHelper) ->


  {log, peek, shallowEq} = Foundation
  {color, point, Matrix, matrix} = Atomic
  {Element, CanvasElement} = EngineCore
  {PointLayout} = Layout

  {stateEpochTest} = StateEpochTestHelper

  suite "Art.Engine.Core.Element", ->
    suite "StateEpoch", ->

      test "new Element is changing", ->
        el = new Element
        assert.eq true, el._getIsChangingElement()

      test "setting Location and Size Layouts", ->
        el = new Element
        el.location = 123
        el.size = 456
        assert.ok el.locationChanged
        assert.ok el.sizeChanged

      test "init size", (done) ->
        p = new Element
          size: 70
        p.onNextReady ->
          assert.eq p.currentSize, point 70
          done()

      test "init currentSize with children", (done) ->
        p = new Element
          size: 70
          new Element size: 30
          new Element size: 40
          new Element size: 50
        p.onNextReady ->
          assert.eq [30, 40, 50], (c.currentSize.x for c in p.children)
          assert.eq p.currentSize, point 70
          done()

      test "init scale", (done) ->
        el = new Element location:123, size:456, scale:2
        el.onNextReady ->
          assert.eq el.currentLocation, point 123
          assert.eq el.currentSize, point 456
          assert.eq el.scale, point 2
          done()

      test "init isMask", ->
        el = new Element isMask:true
        assert.eq el.pendingCompositeMode, "alphamask"

      test "init angle", (done)->
        el = new Element location:123, axis:.5, size:456, angle: Math.PI/2
        el.onNextReady ->
          assert.eq el.currentLocation, point 123
          assert.eq el.currentSize, point 456
          assert.eq el.angle, Math.PI/2
          done()

      stateEpochTest "setting Scale", ->
        el = new Element location:100

        ->
          assert.eq 1.5, el.setScale 1.5
          assert.eq el.locationChanged, false
          assert.eq el.pendingScale, point 1.5
          assert.eq el.scale, point 1

          ->
            assert.eq el.currentLocation, point 100
            assert.eq el.scale, point 1.5

      stateEpochTest "elementToAbsMatrix", ->
        gp = new Element {},
          p = new Element {},
            c = new Element

        ->
          assert.eq gp.elementToAbsMatrix, matrix()
          assert.eq p.elementToAbsMatrix, matrix()
          assert.eq c.elementToAbsMatrix, matrix()
          p.location = 100

          ->
            assert.eq gp.elementToAbsMatrix, matrix()
            assert.eq p.elementToAbsMatrix, Matrix.translate 100
            assert.eq c.elementToAbsMatrix, Matrix.translate 100

      stateEpochTest "absToElementMatrix", ->
        gp = new Element {},
          p = new Element {},
            c = new Element

        ->
          assert.eq gp.absToElementMatrix, matrix()
          assert.eq p.absToElementMatrix, matrix()
          assert.eq c.absToElementMatrix, matrix()
          p.location = 100

          ->
            assert.eq gp.absToElementMatrix, matrix()
            assert.eq p.absToElementMatrix, Matrix.translate -100
            assert.eq c.absToElementMatrix, Matrix.translate -100


      stateEpochTest "complex children structure", ->
        o = new Element {},
          [
            null
            new Element name:"1"
            [
              new Element name:"2"
              null
              new Element name:"3"
            ]
            null
            null
            new Element name:"4"
          ]
        ->
          names = (c.name | 0 for c in o.children)
          assert.eq names, [1, 2, 3, 4]

      stateEpochTest "rootElement", ->
        gp = new Element {},
          p = new Element {},
            c = new Element

        ->
          assert.equal c.getRootElement(), gp
          assert.equal p.getRootElement(), gp
          assert.equal c.getCanvasElement(), null

      stateEpochTest "canvasElement", ->
        ce = new CanvasElement {},
          c = new Element

        ->
          assert.equal c.getRootElement(), ce
          assert.equal c.getCanvasElement(), ce

      stateEpochTest "setting Location and Size with Layout", ->
        el = new Element()
        el.location = 123
        el.size = 456
        ->
          assert.eq el.currentLocation, point 123
          assert.eq el.currentSize, point 456

      test "new Element with layout, location and currentSize changing", ->
        el = new Element
          location:               45
          size:                   123

        assert.ok el.locationChanged
        assert.ok el.sizeChanged

      test "new Element with everything else but layout, location and currentSize changing", ->
        el = new Element
          cursor:                 "pointer"
          elementToParentMatrix:  matrix = Matrix.scale 2
          opacity:                .5
          visible:                false
          compositeMode:          "destOver"
          axis:                   .5
          name:                   "myElement"

        assert.eq true, el._getIsChangingElement()
        assert.eq el.pendingCursor, "pointer"
        assert.eq el.pendingElementToParentMatrix, matrix
        assert.eq el.pendingOpacity, .5
        assert.eq el.pendingVisible, false
        assert.eq el.pendingCompositeMode, "destOver"
        assert.eq el.pendingAxis, point .5
        assert.eq el.pendingName, "myElement"

      test "setting layout with plain object adds to the layout", ->
        el = new Element()
        el.size = wpw: .5
        assert.eq el.pendingSize._hasXLayout, true
        assert.eq el.pendingSize._hasYLayout, true

      stateEpochTest "setting layout with incomplete LinearLayout gets merged", ->
        el = new Element size: 123
        el.size = y:456
        ->
          assert.eq el.currentSize, point 123, 456

      stateEpochTest "setting layout with null clears the layout", ->
        el = new Element size: 123
        el.size = null
        ->
          assert.eq el.currentLocation, point 0

      stateEpochTest "new Element with children", ->
        el = new Element name:"parent",
          new Element name:"foo"
          new Element name:"bar"
        ->
          assert.eq el.name, "parent"
          assert.eq (child.name for child in el.children), ["foo", "bar"]
