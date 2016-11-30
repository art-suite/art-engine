
Foundation = require 'art-foundation'
Events = require 'art-events'
EasingFunctions = require './EasingFunctions'
PersistantAnimator = require './PersistantAnimator'

{
  log, BaseObject
  isFunction, isString, isNumber
  min, max
} = Foundation
{EventedObject} = Events
{interpolate} = PersistantAnimator

module.exports = class PeriodicPersistantAnimator extends PersistantAnimator

  @getter animationPos: ->
    (@getAnimationSeconds() % @_period) / @_period

  @property "period"

  constructor: (_, options = {}) ->
    super
    {@period} = options
