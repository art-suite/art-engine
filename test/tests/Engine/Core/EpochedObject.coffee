Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'

{color, point, matrix, Matrix, perimeter} = Atomic
{inspect, eq, log, peek, isNumber, isFunction} = Foundation
{EpochedObject} = Engine.Core
{PointLayout} = Engine.Layout

class TestableEpochedObject extends EpochedObject
  _drawAreaChanged: ->
  _layoutLocation: -> point 0
  _layoutPropertiesChanged: ->
  _layoutSize: -> point 100
  _layoutSizeForChildren: -> point 100
  _setElementToParentMatrixFromLayout: ->
  _setMarginFromLayout: ->
  _setPaddingFromLayout: ->
  _setSizeFromLayout: ->
  getSizeForChildren: -> point 100
  getChildrenChanged: -> false
  getElementToParentMatrixChanged: -> false
  getParentChanged: -> false
  getPendingChildren: -> []
  getPendingChildrenLayout: -> null
  getPendingLocation: -> new PointLayout
  getPendingMargin: -> 0
  getPendingPadding: -> 0
  getPendingParent: -> null
  getPendingParentSizeForChildren: -> point 100
  getPendingSize: -> new PointLayout 100
  getRedrawRequired: -> false
  getRootElement: -> {}

module.exports = suite: ->
  class EpochedObjectPropertyTester extends TestableEpochedObject
    @concreteProperty
      foo: default: 123

  test "creates private property", ->
    el = new EpochedObjectPropertyTester
    assert.eq el._foo, 123

  test "creates getter", ->
    el = new EpochedObjectPropertyTester
    assert.eq el.foo, 123

  test "creates setter", ->
    el = new EpochedObjectPropertyTester
    el.foo = 124
    el.onNextReady (el) => assert.eq el.foo, 124

  test "init value", ->
    new EpochedObjectPropertyTester foo: 124
    .onNextReady (el) => assert.eq el.foo, 124

  test "init with null value", ->
    new EpochedObjectPropertyTester foo: null
    .onNextReady (el) => assert.eq el.foo, 123

  test "init with undefined value", ->
    new EpochedObjectPropertyTester foo: undefined
    .onNextReady (el) => assert.eq el.foo, 123

  test "set to null after init to 124 results in default value", ->
    new EpochedObjectPropertyTester foo: 124
    .onNextReady (el) =>
      el.foo = null
      el.onNextReady =>
        assert.eq el.foo, 123

  test "set to undefined after init to 124 results in default value", ->
    new EpochedObjectPropertyTester foo: 124
    .onNextReady (el) =>
      el.foo = undefined
      el.onNextReady =>
        assert.eq el.foo, 123

suite "Art.Engine.Core.EpochedObject.concreteProperty.validate", ->

  test "one-arg form", ->
    class EpochedObjectPropertyTester extends TestableEpochedObject
      @concreteProperty
        foo:
          default: 123
          validate: (v) -> isNumber v

    assert.throws ->
      new EpochedObjectPropertyTester foo: [124]

    new EpochedObjectPropertyTester foo: 124
    .onNextReady (el) => assert.eq el.foo, 124

  test "null value gets converted to default before validated", ->
    class EpochedObjectPropertyTester extends TestableEpochedObject
      @concreteProperty
        foo:
          default: 123
          validate: (v) -> isNumber v

    new EpochedObjectPropertyTester foo: null
    .onNextReady (el) => assert.eq el.foo, 123

  test "two-arg form", ->
    class EpochedObjectPropertyTester extends TestableEpochedObject
      @concreteProperty
        foo:
          default: 123
          validate: (v, oldV) -> isNumber(v) && !oldV? || v >= oldV

    assert.throws ->
      new EpochedObjectPropertyTester foo: 122

    new EpochedObjectPropertyTester foo: 124
    .onNextReady (el) => assert.eq el.foo, 124

suite "Art.Engine.Core.EpochedObject.concreteProperty.preprocess", ->

  test "basic preprocessor", ->
    class EpochedObjectPropertyTester extends TestableEpochedObject
      @concreteProperty
        foo:
          default: 123
          preprocess: (v) -> v + 1
    new EpochedObjectPropertyTester foo: 123
    .onNextReady (el) => assert.eq el.foo, 124

  test "preprocessor with two args", ->
    class EpochedObjectPropertyTester extends TestableEpochedObject
      @concreteProperty
        foo:
          default: 123
          preprocess: (v, oldV) -> if oldV? then oldV + v else v
    new EpochedObjectPropertyTester foo: 123
    .onNextReady (el) => assert.eq el.foo, 246

suite "Art.Engine.Core.EpochedObject.concreteProperty.validate and preprocess", ->
  class EpochedObjectPropertyTester extends TestableEpochedObject
    @concreteProperty
      foo:
        default: 123
        validate: (v) -> isNumber v

        # added "| 0" so, if validate executed second, preprocess would work if v was a string
        preprocess: (v) -> (v + 1) | 0

  test "set-valid", ->
    new EpochedObjectPropertyTester foo: 124
    .onNextReady (el) => assert.eq el.foo, 125

  test "validator executes first", ->
    assert.throws ->
      new EpochedObjectPropertyTester foo: "124"

suite "Art.Engine.Core.EpochedObject.concreteProperty.setter", ->

  test "setter is not called for the default value", ->
    class EpochedObjectPropertyTester extends TestableEpochedObject
      @concreteProperty
        foo:
          default: 123
          setter: (v) -> "hi"

    new EpochedObjectPropertyTester()
    .onNextReady (el) =>
      assert.eq el.foo, 123

  test "setter returned value is what gets set", ->
    class EpochedObjectPropertyTester extends TestableEpochedObject
      @concreteProperty
        foo:
          default: 123
          setter: (v) -> "hi"

    new EpochedObjectPropertyTester foo: 123
    .onNextReady (el) =>
      assert.eq el.foo, "hi"

  test "validator executes before setter", ->
    class EpochedObjectPropertyTester extends TestableEpochedObject
      @concreteProperty
        foo:
          default: 123
          validate: (v) -> isNumber v
          setter: (v) -> "hi#{v}"

    assert.throws ->
      new EpochedObjectPropertyTester foo: "123"

    new EpochedObjectPropertyTester foo: 123
    .onNextReady (el) =>
      assert.eq el.foo, "hi123"

  test "setter can have side effects", ->
    class EpochedObjectPropertyTester extends TestableEpochedObject
      @concreteProperty
        bar: default: 123
        foo:
          default: 123
          setter: (v) ->
            @bar = v + 1
            v

    new EpochedObjectPropertyTester foo: 123
    .onNextReady (el) =>
      assert.eq el.bar, 124
      assert.eq el.foo, 123

  test "preprocessor executes before setter", ->
    class EpochedObjectPropertyTester extends TestableEpochedObject
      @concreteProperty
        foo:
          default: 123
          preprocess: (v) -> "preprocess(#{v})"
          setter: (v) -> "setter(#{v})"

    new EpochedObjectPropertyTester foo: 123
    .onNextReady (el) =>
      assert.eq el.foo, "setter(preprocess(123))"

  test "all setter arguments work", ->
    class EpochedObjectPropertyTester extends TestableEpochedObject
      @concreteProperty
        foo:
          default: 123
          validate: (v) -> isNumber v
          preprocess: (v) -> "preprocess(#{v})"
          setter: (v, oldV, rawV, validateAndPreprocess) ->
            assert.throws -> validateAndPreprocess "hi"
            v: v
            oldV: oldV
            rawV: rawV
            validateAndPreprocess_isFunction: isFunction validateAndPreprocess
            validateAndPreprocess_rawV: validateAndPreprocess rawV

    new EpochedObjectPropertyTester foo: 125
    .onNextReady (el) =>
      assert.eq el.foo,
        v: "preprocess(125)"
        oldV: "preprocess(123)"
        rawV: 125
        validateAndPreprocess_isFunction: true
        validateAndPreprocess_rawV: "preprocess(125)"

