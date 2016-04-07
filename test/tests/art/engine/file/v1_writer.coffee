Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'

{point, matrix, Matrix} = Atomic
{inspect, nextTick, eq, log, createObjectTreeFactories} = Foundation
{File:{V1Writer}, newElement} = Engine

{Element} = createObjectTreeFactories "Element", (nodeName, props, children) ->
  newElement nodeName, props, children

suite "Art.Engine.File.V1Writer", ->

  test "Element Animator - Explicit", ->
