
Foundation = require 'art-foundation'
Events = require 'art-events'
EasingFunctions = require './easing_functions'
PersistantAnimator = require './persistant_animator'

{
  log, BaseObject
  isFunction, isString, isNumber
  min, max
} = Foundation
{EventedObject} = Events
{interpolate} = PersistantAnimator

module.exports = class EasingPersistantAnimator extends PersistantAnimator

  @getter "duration easingFunction"

  @getter animationPos: ->
    min 1, @getAnimationSeconds() / @_duration

  @setter
    duration: (d) ->
      @_duration = if isNumber(d) then max .001, d else .25

    easingFunction: (f) ->
      @_easingFunction = f
      if isString f
        unless @_easingFunction = EasingFunctions[f]
          console.warn "invalid easing easingFunction: #{f}"

      @_easingFunction ||= EasingFunctions.linear

  constructor: (_, options = {}) ->
    super
    @setEasingFunction options.f || options.easingFunction
    @setDuration if options.d? then options.d else options.duration

  animate: () ->
    {startValue, toValue, animationPos, easingFunction} = @
    @stop() if 1 == animationPos
    interpolate startValue, toValue, easingFunction animationPos

