Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'

{color, point, matrix, Matrix, perimeter} = Atomic
{inspect, eq, log, peek} = Foundation
{EpochedObject} = Engine.Core

# suite "Art.Engine.Core.EpochedObject.concreteProperty", ->
#   class EpochedObjectPropertyTester extends EpochedObject
#     @concreteProperty
#       foo: default: 123

#   test "creates private property", ->
#     el = new EpochedObjectPropertyTester
#     assert.ok "_foo" in Object.keys el


#   test "default value", ->
#     el = new EpochedObjectPropertyTester
#     .onNextReady()
#     .then =>
#       self.el = el
#       assert.eq el.foo, 123
