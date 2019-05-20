Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
{Core:EngineCore, Layout} = require 'art-engine'
StateEpochTestHelper = require './StateEpochTestHelper'

HtmlCanvas = Foundation.Browser.DomElementFactories.Canvas
{log, peek, shallowEq} = Foundation
{color, point, Matrix, matrix} = Atomic
{Element, CanvasElement} = require 'art-engine/Factories'
{PointLayout} = Layout

{stateEpochTest} = StateEpochTestHelper

module.exports = suite: ->

  test "Element is changing", ->
    el = Element()
    assert.eq true, el._getIsChangingElement()

  test "setting Location and Size Layouts", ->
    el = Element()
    el.location = 123
    el.size = 456
    assert.ok el.locationChanged
    assert.ok el.sizeChanged

  test "init size", ->
    p = Element
      size: 70
    p.onNextReady ->
      assert.eq p.currentSize, point 70

  test "init currentSize with children", ->
    p = Element
      size: 70
      Element size: 30
      Element size: 40
      Element size: 50
    p.onNextReady ->
      assert.eq [30, 40, 50], (c.currentSize.x for c in p.children)
      assert.eq p.currentSize, point 70

  test "init scale", ->
    el = Element location:123, size:456, scale:2
    el.onNextReady ->
      assert.eq el.currentLocation, point 123
      assert.eq el.currentSize, point 456
      assert.eq el.scale, point 2

  test "init isMask", ->
    el = Element isMask:true
    assert.eq el.pendingCompositeMode, "alphaMask"

  test "init angle", ->
    el = Element location:123, axis:.5, size:456, angle: Math.PI/2
    el.onNextReady ->
      assert.eq el.currentLocation, point 123
      assert.eq el.currentSize, point 456
      assert.eq el.angle, Math.PI/2

  stateEpochTest "setting Scale", ->
    el = Element location:100

    ->
      assert.eq point(1.5), el.setScale 1.5
      assert.eq el.locationChanged, false
      assert.eq el.pendingScale, point 1.5
      assert.eq el.scale, point 1

      ->
        assert.eq el.currentLocation, point 100
        assert.eq el.scale, point 1.5

  stateEpochTest "elementToAbsMatrix", ->
    gp = Element {},
      p = Element {},
        c = Element()

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
    gp = Element {},
      p = Element {},
        c = Element()

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
    o = Element {},
      [
        null
        Element name:"1"
        [
          Element name:"2"
          null
          Element name:"3"
        ]
        null
        null
        Element name:"4"
      ]
    ->
      names = (c.name | 0 for c in o.children)
      assert.eq names, [1, 2, 3, 4]

  stateEpochTest "rootElement", ->
    gp = Element {},
      p = Element {},
        c = Element()

    ->
      assert.equal c.getRootElement(), gp
      assert.equal p.getRootElement(), gp
      assert.equal c.getCanvasElement(), null

  stateEpochTest "canvasElement", ->
    ce = CanvasElement canvas: HtmlCanvas(),
      c = Element()

    ->
      assert.equal c.getRootElement(), ce
      assert.equal c.getCanvasElement(), ce

  stateEpochTest "setting Location and Size with Layout", ->
    el = Element()
    el.location = 123
    el.size = 456
    ->
      assert.eq el.currentLocation, point 123
      assert.eq el.currentSize, point 456

  test "Element with layout, location and currentSize changing", ->
    el = Element
      location:               45
      size:                   123

    assert.ok el.locationChanged
    assert.ok el.sizeChanged

  test "Element with everything else but layout, location and currentSize changing", ->
    el = Element
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
    el = Element()
    el.size = wpw: .5
    assert.eq el.pendingSize._hasXLayout, true
    assert.eq el.pendingSize._hasYLayout, true

  stateEpochTest "changing size completely replaces old size", ->
    el = Element size: 123
    el.size = y:456
    ->
      assert.eq el.currentSize, point 100, 456

  stateEpochTest "setting layout with null clears the layout", ->
    el = Element size: 123
    el.size = null
    ->
      assert.eq el.currentLocation, point 0

  stateEpochTest "Element with children", ->
    el = Element name:"parent",
      Element name:"foo"
      Element name:"bar"
    ->
      assert.eq el.name, "parent"
      assert.eq (child.name for child in el.children), ["foo", "bar"]
