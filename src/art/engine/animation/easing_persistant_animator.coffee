
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

  @getter "duration", "function"

  @getter animationPos: ->
    min 1, @getDeltaSecond() / @_duration

  @setter
    duration: (d) ->
      @_duration = if isNumber(d) then max .001, d else .25

    function: (f) ->
      @_function = f
      if isString f
        unless @_function = EasingFunctions[f]
          console.warn "invalid easing function: #{f}"

      @_function ||= EasingFunctions.linear

  constructor: (_, options = {}) ->
    super
    @setFunction options.f || options.function
    @setDuration if options.d? then options.d else options.duration

  animate: (fromValue, toValue, animationSecond) ->
    if 1 < animationPos = animationSecond / @_duration
      @_active = false
      animationPos = 1

    interpolate fromValue, toValue, easedPos = @_function animationPos

