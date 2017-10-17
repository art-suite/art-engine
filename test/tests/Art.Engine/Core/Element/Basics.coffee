Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
Engine = require 'art-engine'

{point, matrix, Matrix} = Atomic
{inspect, nextTick, eq, log, merge} = Foundation
{FillElement, BlurElement, RectangleElement, Element} = Engine

suite "Art.Engine.Core.Element.basics", ->
  test "_initFields happened", ->
    e = new Element

    # Element#_initFields
    assert.eq e._rootElement, e
    assert.eq e._elementToAbsMatrix, null
    assert.eq e._absToElementMatrix, null
    assert.eq e._parentToElementMatrix, null

    # ElementBase#_initFields
    assert.eq e.remoteId, null

    # EpochedObject#_initFields
    assert.eq e.__stateEpochCount, 0
