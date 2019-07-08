'use strict';
Foundation = require 'art-foundation'
{EventEpoch} = require 'art-events'
StateEpoch = require './StateEpoch'
DrawEpoch = require './Drawing/DrawEpoch'
IdleEpoch = require './IdleEpoch'

ArtFrameStats = require 'art-frame-stats'

{
  log, requestAnimationFrame, miniInspect, time, arrayWithout, currentSecond, Epoch
  globalCount
  isPlainObject
  durationString
  fastBind
} = Foundation

toMs = (s) -> (s*1000).toFixed(1) + "ms"
{eventEpoch} = EventEpoch
{drawEpoch} = DrawEpoch
{stateEpoch} = StateEpoch
{idleEpoch} = IdleEpoch

class DummyEpoch extends Epoch
  @singletonClass()

{dummyEpoch} = DummyEpoch
fluxEpoch = reactEpoch = dummyEpoch

module.exports = class GlobalEpochCycle extends Epoch
  @singletonClass()

  @classGetter
    activeCanvasElements: -> @globalEpochCycle.activeCanvasElements

  constructor: ->
    super
    @cycleQueued = false
    @processingCycle = false
    @activeCanvasElements = []
    @_fluxOnIdleOkUntil = currentSecond()
    # @_resetThisCyclesStats()

    idleEpoch.queueNextEpoch  =
    stateEpoch.queueNextEpoch =
    drawEpoch.queueNextEpoch  =
    eventEpoch.queueNextEpoch = => @queueNextEpoch()

    # If a pointerClick causes the full global epoch to be processed, frameTime is all wrong for animations.
    # I think it's OK to just push the event-epoch out (which should allow the request-image-dialog to fire)
    # eventEpoch.flushEpochNow  = => @flushEpochNow()

    eventEpoch.logEvent = ArtFrameStats.logEvent # (name, id) => @logEvent name, id

  allowFluxOnIdle: (nextNSeconds)->
    @_fluxOnIdleOkUntil = currentSecond() + nextNSeconds

  # _resetThisCyclesStats: ->
  #   @performanceSamples = {}

  ############################
  # FrameStats: DEPRICATED - use ArtFrameStats
  ############################

  logEvent:             ArtFrameStats.logEvent
  startTimePerformance: ArtFrameStats.startTimer
  endTimePerformance:   ArtFrameStats.endTimer

  # addPerformanceSample: (name, value) ->
  #   throw new Error "@performanceSamples not set" unless @performanceSamples
  #   @performanceSamples[name] = (@performanceSamples[name] || 0) + value
  #   # @fluxFrameTime = @reactFrameTime = @eventFrameTime = @idleFrametime = @aimUpdateFrameTime = @drawFrameTime = 0

  # timerStack = []
  # timePerformance: (name, f) ->
  #   start = @startTimePerformance()
  #   f()
  #   @endTimePerformance name, start
  # logEvent: (name, id) ->
  #   @globalEpochStats?.logEvent name, id

  # startTimePerformance: ->
  #   start = currentSecond()
  #   timerStack.push 0
  #   start

  # endTimePerformance: (name, start) ->
  #   subTimeTotal = timerStack.pop()
  #   elapsedTime = currentSecond() - start
  #   if (tsl = timerStack.length) > 0
  #     timerStack[tsl-1] += elapsedTime

  #   @addPerformanceSample name, elapsedTime - subTimeTotal

  ############################
  # </FrameStats>
  ############################
  @getter
    numActivePointers: ->
      count = 0
      for canvasElement in @activeCanvasElements
        count += canvasElement.getNumActivePointers()
      count

    idle: ->
      reactEpoch.getEpochLength() == 0 &&
      stateEpoch.getEpochLength() == 0 &&
      eventEpoch.getEpochLength() == 0 #&&
      # @getNumActivePointers() == 0

    epochLength: ->
      idleEpoch.getEpochLength() +
      eventEpoch.getEpochLength() +
      stateEpoch.getEpochLength() +
      reactEpoch.getEpochLength() +
      fluxEpoch.getEpochLength()

  @getter
    idleEpoch : -> idleEpoch
    eventEpoch: -> eventEpoch
    stateEpoch: -> stateEpoch
    drawEpoch:  -> drawEpoch
    reactEpoch: -> reactEpoch
    fluxEpoch : -> fluxEpoch


  includeReact: (epoch) -> (reactEpoch = epoch).queueNextEpoch = => @queueNextEpoch()
  includeFlux:  (epoch) -> (fluxEpoch  = epoch).queueNextEpoch = => @queueNextEpoch()

  detachCanvasElement: (toRemoveCe) ->
    @activeCanvasElements = arrayWithout @activeCanvasElements, toRemoveCe

  attachCanvasElement: (toAddCe) ->
    @activeCanvasElements.push toAddCe

  processFluxEpoch:  ->
    start = @startTimePerformance()
    fluxEpoch.processEpoch()
    @endTimePerformance "flux", start

  processIdleEpoch:  ->
    start = @startTimePerformance()
    idleEpoch?.processEpoch()
    @endTimePerformance "idle", start

  processEventEpoch: ->
    start = @startTimePerformance()
    eventEpoch.processEpoch()
    @endTimePerformance "event", start

  processReactEpoch: ->
    start = @startTimePerformance()
    reactEpoch.processEpoch()
    @endTimePerformance "react", start

  processStateEpoch: ->
    start = @startTimePerformance()
    stateEpoch.processEpoch()
    @endTimePerformance "aim", start

  processDrawEpoch:  ->
    start = @startTimePerformance()
    drawEpoch.processEpoch()
    @endTimePerformance "draw", start

  flushEpochNow: ->
    return if @processingCycle
    @processingCycle = true
    @_processCycleExceptDraw()
    @processingCycle = false

  _processCycleExceptDraw: ->
    @processEventEpoch()
    @processFluxEpoch() #if @getIdle() || currentSecond() < @_fluxOnIdleOkUntil
    @processIdleEpoch() if @getIdle()

    reactEpoch.updateGlobalCounts()
    @processReactEpoch()
    globalCount "reactEpochAfter", reactEpoch.getEpochLength()

    stateEpoch.updateGlobalCounts()
    @processStateEpoch()
    globalCount "stateEpochAfter", stateEpoch.getEpochLength()

  processEpochItems: (items) ->
    fluxEpoch._frameSecond =
    idleEpoch._frameSecond =
    eventEpoch._frameSecond =
    reactEpoch._frameSecond =
    stateEpoch._frameSecond =
    drawEpoch._frameSecond = @_frameSecond

    Foundation.resetGlobalCounts()
    # startTime = currentSecond()

    ArtFrameStats.startFrame()

    # @_resetThisCyclesStats()
    @processingCycle = true
    @_processCycleExceptDraw()

    # animations triggered on element creation cannot be properly initalized until
    # all other properties have been applied - i.e. until stateEpoch.onNextReady
    # However, animations triggered on element creation need to set their start-state before
    # the next redraw. Therefor, we allow a second iteration of non-draw epochs.
    # ALSO: some Components need to capture ElementSizes to refine layout (VerticalStackPager), so they may need one extra cycle.
    # SBD: Changed on 12-20-2015 to only reprocess StateEpoch. That's all the animators need.
    #   In particular, I don't want to process the eventEpoch twice since animators trigger their frames
    #   each time we process the eventEpoch.
    #   We could process the React epoch again, but we don't need it with the new Art.EngineRemote code
    @processStateEpoch() if stateEpoch.getEpochLength() > 0

    drawCount = drawEpoch.epochLength
    @processDrawEpoch()
    @processingCycle = false

    # processTime = currentSecond() - @cycleStartTime
    # @log cycleTime:"#{1000 * cycleTime | 0}ms", processTime:"#{1000 * processTime | 0}ms", events:events, states:states

    if @getEpochLength() > 0
      # console.warn "GlobalEpochCycle: processed maximum state and event cycles (#{@getEpochLength()}) before Draw."
      @queueNextEpoch()

    # if drawCount > 0
    #   @globalEpochStats?.add startTime, currentSecond() - startTime, @performanceSamples

    ArtFrameStats.endFrame()
