define [
  'art-foundation'
  'art-atomic'
  'art-canvas'
  'art-engine'
  './state_epoch_test_helper'
], (Foundation, Atomic, Canvas, Engine, StateEpochTestHelper) ->
  {color, point, matrix, Matrix, perimeter} = Atomic
  {inspect, eq, log, peek} = Foundation
  {ElementBase, StateEpoch} = Engine.Core
  {PointLayout} = Engine.Layout

  {stateEpochTest} = StateEpochTestHelper
  {stateEpoch} = StateEpoch

  class ElementBaseTest extends ElementBase
    @coreProperty
      # minimum properties require to be compatible with Element for StateEpoch processing
      parent:                 default: null
      elementToParentMatrix:  default: new Matrix,            preprocess: (v) -> matrix v
      currentSize:            default: point 100
      children:               default: []
      isFilterSource:         default: false

    @drawAreaProperty
      # basic property
      radius:                 default: 0

    @drawProperty
      # property with validator
      cursor:                 default: null,                  validate:   (v) -> !v || typeof v is "string"

      # property with preprocessor
      color:                  default: "#ff0",                preprocess: (c) -> color c

      # property with setter
      # This would be a virtual property if we didn't want to also store the gray value as its own unit
      gray:                                                   setter: (v) -> color v, v, v

    @virtualProperty
      location:
        preprocess: (l) -> point l
        setter: (l) -> @setElementToParentMatrix @getPendingElementToParentMatrix().withLocation l
        getter: (o) -> o._elementToParentMatrix.getLocation()

    @getter
      redrawRequired: -> true

    getPendingParentSizeForChildren: ->
      point 10

    @layoutProperty
      padding:  default: 0
      margin:  default: 0
      location: default: 0, preprocess: (v) -> new PointLayout v
      size:     default: 1, preprocess: (v) -> new PointLayout v
      currentPadding: default: perimeter()
      childrenLayout: default: null

    _setPaddingFromLayout: ->
    _setMarginFromLayout: ->
    _setSizeFromLayout: ->
    _setLocationFromLayout: ->

    # getPendingLocation: -> new PointLayout
    # getPendingSize: -> new PointLayout
    # getPendingPadding:

  suite "Art.Engine.Core.ElementBase", ->
    test "_color in instance and _pendingState", ->
      ebd = new ElementBaseTest
      assert.ok "_color" in Object.keys ebd
      assert.ok "_color" in Object.keys ebd._pendingState

    test "init with default color property", ->
      ebd = new ElementBaseTest
      assert.eq ebd.color, c = color "#ff0"
      assert.eq ebd.color, c
      assert.eq ebd.getColor(), c
      assert.eq ebd.pendingColor, c
      assert.eq ebd.getPendingColor(), c

    test "init with basic property", ->
      ebd = new ElementBaseTest radius: 1

      assert.eq ebd.radiusChanged, true
      assert.eq ebd.pendingRadius, 1

    test "init with preprocessed property", ->
      ebd = new ElementBaseTest color: "red"
      assert.eq ebd.colorChanged, true
      assert.eq ebd.pendingColor, color "red"

    test "init with invalid property", ->
      errorCount = 0
      try
        ebd = new ElementBaseTest cursor: {}
      catch e
        errorCount++

      assert.eq errorCount, 1

    test "init with valid property", ->
      ebd = new ElementBaseTest cursor: "pointer"

      assert.eq ebd.cursorChanged, true
      assert.eq ebd.pendingCursor, "pointer"

    test "set basic property", ->
      ebd = new ElementBaseTest
      before = ebd.radius
      ebd.radius = 1

      assert.eq ebd.radius, before
      assert.eq ebd.radiusChanged, true
      assert.eq ebd.pendingRadius, 1

    test "set with preprocessor", ->
      ebd = new ElementBaseTest
      before = ebd.color
      ebd.color = "red"

      assert.eq ebd.color, before
      assert.eq ebd.colorChanged, true
      assert.eq ebd.pendingColor, color "red"

    test "set with invalid property", ->
      ebd = new ElementBaseTest
      errorCount = 0
      try
        ebd.cursor = {}
      catch e
        errorCount++

      assert.eq errorCount, 1
      assert.eq ebd.cursorChanged, false

    test "set with valid property", ->
      ebd = new ElementBaseTest
      ebd.cursor = "pointer"

      assert.eq ebd.cursorChanged, true
      assert.eq ebd.pendingCursor, "pointer"

    test "set with setter", ->
      ebd = new ElementBaseTest
      before = ebd.color
      ebd.gray = .5

      assert.eq ebd.color, before
      assert.eq ebd.pendingGray, color .5
      assert.eq ebd.grayChanged, true

    test "set, get, pendingGet color property", ->
      ebd = new ElementBaseTest
      ebd.color = "white"
      assert.eq ebd.color, color "#ff0"
      assert.eq ebd.pendingColor, color "white"

      ebd.setColor "brown"
      assert.eq ebd.color, color "#ff0"
      assert.eq ebd.pendingColor, color "brown"

    stateEpochTest "colorChanged", ->
      ebd = new ElementBaseTest

      ebd.color = "white"
      assert.eq true, ebd.colorChanged
      assert.eq true, ebd.getColorChanged()

      ->
        assert.eq false, ebd.colorChanged
        assert.eq false, ebd.getColorChanged()

    test "applyChanges && _drawPropertiesChanged override", ->
      ebd = new ElementBaseTest
      count = 0
      ebd._drawPropertiesChanged = -> count++

      ebd.color = color "white"
      assert.eq ebd.color, color "#ff0"
      assert.eq true, ebd.colorChanged
      assert.eq ebd.pendingColor, color "white"

      ebd._applyStateChanges()
      assert.eq ebd.color, color "white"
      assert.eq false, ebd.colorChanged
      assert.eq ebd.pendingColor, color "white"

      assert.eq count, 1

    test "change properties adds element to stateEpoch.changingElements exactly once", ->
      countBefore = stateEpoch.epochLength
      ebd = new ElementBaseTest
      ebd.color = color "red"
      assert.eq stateEpoch.epochLength, countBefore + 1
      assert.eq true, stateEpoch._isChangingElement ebd

      ebd.color = color "gold"
      assert.eq stateEpoch.epochLength, countBefore + 1

    stateEpochTest "stateEpoch", ->
      stateEpoch.flushEpochNow()
      ebd = new ElementBaseTest
      ebd.color = color "red"
      ->
        assert.eq ebd.color, ebd.pendingColor
        assert.eq ebd.color, color "red"
        assert.eq false, ebd.colorChanged

    test "metaProperties", ->
      ebd = new ElementBaseTest
      assert.ok ebd.metaProperties.parent
      assert.ok ebd.metaProperties.elementToParentMatrix

      assert.eq typeof ebd.metaProperties.color.externalName, "string"
      assert.eq typeof ebd.metaProperties.color.internalName, "string"
      assert.eq typeof ebd.metaProperties.color.preprocessor, "function"
      assert.ok ebd.metaProperties.color.hasOwnProperty "defaultValue"

    test "preprocessProperties", ->
      ebd = new ElementBaseTest
      props =
        foo: "non-existent properties are left alone instead of erroring"
        radius: "something completely wrong but with no preprocessor"
        color: "#f00"
      ebd.preprocessProperties props
      assert.eq props,
        foo: "non-existent properties are left alone instead of erroring"
        radius: "something completely wrong but with no preprocessor"
        color: color "#f00"

    test "get[Pending]PropertyValues", ->
      ebd = new ElementBaseTest color:"red"
      assert.eq ebd.getPendingPropertyValues(["foo", "radius", "color"]), radius: 0, color: color "red"
      assert.eq ebd.getPropertyValues(["foo", "radius", "color"]), radius: 0, color: color "#ff0"

    test "setProperties only alters specified props", ->
      ebd = new ElementBaseTest color:"red", cursor: "pointer"
      ebd.setProperties color:"blue"
      assert.eq ebd.getPendingPropertyValues(["color", "cursor"]), cursor: "pointer", color: color "blue"

    test "replaceProperties sets all properties, using defaults as needed", ->
      ebd = new ElementBaseTest color:"red", cursor: "pointer"
      ebd.replaceProperties color:"blue"
      assert.eq ebd.getPendingPropertyValues(["color", "cursor"]), cursor: null, color: color "blue"
