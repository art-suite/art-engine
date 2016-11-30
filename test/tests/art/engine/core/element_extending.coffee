Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
Engine = require 'art-engine'

{rgbColor, point, matrix, Matrix, perimeter} = Atomic
{inspect, eq, log, peek} = Foundation
{ElementBase, Element, StateEpoch} = Engine.Core
{PointLayout} = Engine.Layout

{stateEpoch} = StateEpoch

class ElementTest extends Element

  @drawAreaProperty
    # basic property
    radius:                 default: 0

  @drawProperty
    # property with validator
    cursor:                 default: null,                  validate:   (v) -> !v || typeof v is "string"

    # property with preprocessor
    color:                  default: "#ff0",                preprocess: (c) -> rgbColor c

    # property with setter
    # This would be a virtual property if we didn't want to also store the gray value as its own unit
    gray:                                                   setter: (v) -> rgbColor v, v, v

module.exports = suite: ->
  test "_color in instance and _pendingState", ->
    ebd = new ElementTest
    assert.ok "_color" in Object.keys ebd
    assert.ok "_color" in Object.keys ebd._pendingState

  test "init with default color property", ->
    ebd = new ElementTest
    assert.eq ebd.color, c = rgbColor "#ff0"
    assert.eq ebd.color, c
    assert.eq ebd.getColor(), c
    assert.eq ebd.pendingColor, c
    assert.eq ebd.getPendingColor(), c

  test "init with basic property", ->
    ebd = new ElementTest radius: 1

    assert.eq ebd.radiusChanged, true
    assert.eq ebd.pendingRadius, 1

  test "init with preprocessed property", ->
    ebd = new ElementTest color: "red"
    assert.eq ebd.colorChanged, true
    assert.eq ebd.pendingColor, rgbColor "red"

  test "init with invalid property", ->
    errorCount = 0
    try
      ebd = new ElementTest cursor: {}
    catch e
      errorCount++

    assert.eq errorCount, 1

  test "init with valid property", ->
    ebd = new ElementTest cursor: "pointer"

    assert.eq ebd.cursorChanged, true
    assert.eq ebd.pendingCursor, "pointer"

  test "set basic property", ->
    ebd = new ElementTest
    before = ebd.radius
    ebd.radius = 1

    assert.eq ebd.radius, before
    assert.eq ebd.radiusChanged, true
    assert.eq ebd.pendingRadius, 1

  test "set with preprocessor", ->
    ebd = new ElementTest
    before = ebd.color
    ebd.color = "red"

    assert.eq ebd.color, before
    assert.eq ebd.colorChanged, true
    assert.eq ebd.pendingColor, rgbColor "red"

  test "set with invalid property", ->
    ebd = new ElementTest
    errorCount = 0
    try
      ebd.cursor = {}
    catch e
      errorCount++

    assert.eq errorCount, 1
    assert.eq ebd.cursorChanged, false

  test "set with valid property", ->
    ebd = new ElementTest
    ebd.cursor = "pointer"

    assert.eq ebd.cursorChanged, true
    assert.eq ebd.pendingCursor, "pointer"

  test "set with setter", ->
    ebd = new ElementTest
    before = ebd.color
    ebd.gray = .5

    assert.eq ebd.color, before
    assert.eq ebd.pendingGray, rgbColor .5
    assert.eq ebd.grayChanged, true

  test "set, get, pendingGet color property", ->
    ebd = new ElementTest
    ebd.color = "white"
    assert.eq ebd.color, rgbColor "#ff0"
    assert.eq ebd.pendingColor, rgbColor "white"

    ebd.setColor "brown"
    assert.eq ebd.color, rgbColor "#ff0"
    assert.eq ebd.pendingColor, rgbColor "brown"

  test "colorChanged", ->
    ebd = new ElementTest

    ebd.color = "white"
    assert.eq true, ebd.colorChanged
    assert.eq true, ebd.getColorChanged()

    ebd.onNextReady ->
      assert.eq false, ebd.colorChanged
      assert.eq false, ebd.getColorChanged()

  test "applyChanges && _drawPropertiesChanged override", ->
    ebd = new ElementTest
    count = 0
    ebd._drawPropertiesChanged = -> count++

    ebd.color = rgbColor "white"
    assert.eq ebd.color, rgbColor "#ff0"
    assert.eq true, ebd.colorChanged
    assert.eq ebd.pendingColor, rgbColor "white"

    ebd._applyStateChanges()
    assert.eq ebd.color, rgbColor "white"
    assert.eq false, ebd.colorChanged
    assert.eq ebd.pendingColor, rgbColor "white"

    assert.eq count, 1

  test "change properties adds element to stateEpoch.changingElements exactly once", ->
    countBefore = stateEpoch.epochLength
    log countBefore:countBefore
    ebd = new ElementTest
    # ebd.color = rgbColor "red"
    # assert.eq stateEpoch.epochLength, countBefore + 1
    assert.eq true, stateEpoch._isChangingElement ebd

    ebd.color = rgbColor "gold"
    assert.eq stateEpoch.epochLength, countBefore + 1

  test "stateEpoch", ->
    stateEpoch.flushEpochNow()
    ebd = new ElementTest
    ebd.color = rgbColor "red"
    ebd.onNextReady ->
      assert.eq ebd.color, ebd.pendingColor
      assert.eq ebd.color, rgbColor "red"
      assert.eq false, ebd.colorChanged

  test "metaProperties", ->
    ebd = new ElementTest
    assert.ok ebd.metaProperties.parent
    assert.ok ebd.metaProperties.elementToParentMatrix

    assert.eq typeof ebd.metaProperties.color.externalName, "string"
    assert.eq typeof ebd.metaProperties.color.internalName, "string"
    assert.eq typeof ebd.metaProperties.color.preprocessor, "function"
    assert.ok ebd.metaProperties.color.hasOwnProperty "defaultValue"

  test "preprocessProperties", ->
    ebd = new ElementTest
    props =
      foo: "non-existent properties are left alone instead of erroring"
      radius: "something completely wrong but with no preprocessor"
      color: "#f00"
    ebd.preprocessProperties props
    assert.eq props,
      foo: "non-existent properties are left alone instead of erroring"
      radius: "something completely wrong but with no preprocessor"
      color: rgbColor "#f00"

  test "get[Pending]PropertyValues", ->
    ebd = new ElementTest color:"red"
    assert.eq ebd.getPendingPropertyValues(["foo", "radius", "color"]), radius: 0, color: rgbColor "red"
    assert.eq ebd.getPropertyValues(["foo", "radius", "color"]), radius: 0, color: rgbColor "#ff0"

  test "setProperties only alters specified props", ->
    ebd = new ElementTest color:"red", cursor: "pointer"
    ebd.setProperties color:"blue"
    assert.eq ebd.getPendingPropertyValues(["color", "cursor"]), cursor: "pointer", color: rgbColor "blue"

  test "replaceProperties sets all properties, using defaults as needed", ->
    ebd = new ElementTest color:"red", cursor: "pointer"
    ebd.replaceProperties color:"blue"
    assert.eq ebd.getPendingPropertyValues(["color", "cursor"]), cursor: null, color: rgbColor "blue"
