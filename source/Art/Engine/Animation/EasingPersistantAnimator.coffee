
Foundation = require 'art-foundation'
Events = require 'art-events'
EasingFunctions = require './EasingFunctions'
PersistantAnimator = require './PersistantAnimator'

{
  log, BaseClass
  isFunction, isString, isNumber
  min, max
} = Foundation
{EventedObject} = Events
{interpolate} = PersistantAnimator

module.exports = class EasingPersistantAnimator extends PersistantAnimator

  @getter "duration easingFunction delay"

  @getter animationPos: ->
    s = @getAnimationSeconds()
    {duration, delay} = @
    if s <= delay
      0
    else
      s -= delay
      min 1, s / @_duration

  @setter
    duration: (d) ->
      @_duration = if isNumber(d) then max .001, d else .25

    delay: (d) ->
      @_delay = if isNumber(d) then max 0, d else 0

    easingFunction: (f) ->
      @_easingFunction = f
      if isString f
        unless @_easingFunction = EasingFunctions[f]
          console.warn "invalid easing easingFunction: #{f}"

      @_easingFunction ||= EasingFunctions.easeInQuad

  constructor: (_, options = {}) ->
    super
    @setEasingFunction options.f || options.easingFunction
    {d, @duration = d, @delay} = options

  animate: () ->
    {startValue, toValue, animationPos, easingFunction} = @
    @stop() if 1 == animationPos
    interpolate startValue, toValue, easingFunction animationPos

