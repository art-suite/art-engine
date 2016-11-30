###
Useful ideas about optimizing animations and garbage collection: http://blog.artillery.com/2012/10/browser-garbage-collection-and-framerate.html

See Foundation.Transaction for most constructor options.

from-values are either explicitly specified in the constructor, or any other properties defined
  in the constructor will have their from-values saved during construction.

The animation is automatically started on construction UNLESS there are no to-values.
If there are no to-values specified, then you must manually, later, call "start". At that point, all to-values
are set to the current values.
###

{currentSecond, min, max, Transaction, inspect, inspectLean, log, BaseObject} = require 'art-foundation'
{rgbColor, Color, point, Point, rect, Rectangle, matrix, Matrix} = require 'art-atomic'
{Event, EventEpoch, EventedMixin} = require 'art-events'
EasingFunctions = require './EasingFunctions'
{eventEpoch} = EventEpoch

module.exports = class Animator extends EventedMixin BaseObject
  @animate: (objects, options) -> new Animator objects, options

  # see Transaction for objects and primary options
  # additional options:
  #   duration: 0.5 # duration of animation in seconds
  #   f: "linear" # Can be:
  #     (string) interpolation function name from EasingFunctions
  #     (p) ->: function from values in the range [0,1] to values in the range [0,1]
  #       Example outputs:
  #         0   output >> set properties from fromValues
  #         0.5 output >> set properties halfway between fromValues and toValues
  #         1   output >> set properties from toValues
  #       Input values are guaranteed to be [0,1].
  #       Output values are allowed outside [0,1]. The "bounce" EasingFunctions do exactly this.
  #   on:          # specify event handlers
  #     done: ->   # fires when the animation completes
  #     update: -> # fires every time the target object's animated values updated
  #     start: ->  # fires when the animation starts
  #     abort: ->  # fires when the animation aborts
  #   fixedStep: null # null or float >0, <= 1.
  #     If set, instead of running the animation against the clock, advance the animation
  #     frame-by-frame from 0 to 1 in fixedStep increments stops when >= 1
  #   then: {} # specify an animation to start when this is done using this code:
  #     objects = @then.objects || @then.object || @objects
  #     new Animator objects, @then
  constructor: (objects, options = {})->
    super

    @transaction = new Transaction objects, options

    @fixedStep = options.fixedStep
    throw new Error "fixedStep must be > 0" if @fixedStep && @fixedStep <= 0

    @duration = options.duration || 0.25
    @f = options.f
    if !@f
      @f = EasingFunctions[@fName = "easeInQuad"]
    else if typeof @f == "string"
      @fName = @f
      @f = EasingFunctions[@f]
    else
      @fName = "custom"
    @on options.on if options.on
    @then = options.then

    @start() #if @transaction.hasToValues || @transaction.hasFromValues

  inspect: (inspector)->
    inspector.put @classPathName
    inspector.put " duration: #{@duration}, function: #{@fName}"
    inspector.put ", activated, frames: #{@frames}, pos: #{@pos}" if @activated
    inspector.put ", aborted" if @aborted
    inspector.put ", deactivated" if @deactivated
    @transaction.inspectParts inspector

  ################################################
  # PUBLIC API - also see Transaction's API
  ################################################
  abort: ->
    unless @aborted
      eventEpoch.logEvent "animationAborted", @getObjectId()
      @aborted = true
      @deactivateAnimation()
      @queueEvent "abort"

  start: ->
    @transaction.saveFromValues()
    @transaction.saveToValues()
    @transaction.optimize()
    @updateValues 0
    @activateAnimation()
    @frames = 0

    eventEpoch.queue =>
      return if @deactivated
      @updateValues 0
      eventEpoch.logEvent "animation", @getObjectId()
      @startTime = currentSecond()
      @queueEvent "start"

      eventEpoch.queue => @advance()

  # jump to the end of the animation, fire any "done" events
  finish: ->
    @updateValues 1
    @done()

  @getter
    pos: ->
      if @fixedStep
        @frames * @fixedStep
      else
        (@now - @startTime) / @duration

    objects: -> @transaction.objects

  ################################################
  # PRIVATE API
  ################################################
  activateAnimation: ->
    return if @activated
    @activated = true
    # @log activateAnimation:@
    for animatedObject in @objects
      # @log "  for: #{inspect animatedObject}"
      if animatedObject._activeAnimator
        # @log "#{animatedObject.classPathName} already has _activeAnimator... aborting last animation to start this one"
        animatedObject._activeAnimator.abort()
      animatedObject._activeAnimator = @

  deactivateAnimation: ->
    return if @deactivated
    @deactivated = true
    for animatedObject in @objects
      if animatedObject._activeAnimator != @
        @log "INTERNAL WARNING - animatedObject._activeAnimator should == @"
        @log "  animatedObject: (#{inspect animatedObject, 1}"
        @log "  animatedObject._activeAnimator: (#{inspect animatedObject._activeAnimator, 1}"
        @log "  @: (#{inspect @, 1}"
      delete animatedObject._activeAnimator

  advance: ->
    return if @aborted || @deactivated
    @frames++
    @now = currentSecond()
    pos = @pos

    if pos < 1
      @updateValues @f pos
      eventEpoch.queue => @advance()
    else
      @updateValues 1
      @done()

  done: ->
    return if @aborted
    eventEpoch.logEvent "animation", @getObjectId()
    @deactivateAnimation()
    @queueEvent "done"
    @nextAnimation()

  nextAnimation: ->
    return unless @then
    objects = @then.objects || @then.object || @objects
    new Animator objects, @then

  updateValues: (p) ->
    # @log updateValues: p:p
    @transaction.interpolate p
    @queueEvent "update", p:p
