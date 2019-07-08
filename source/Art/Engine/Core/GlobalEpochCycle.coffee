'use strict';

{log, arrayWithout, currentSecond} = require 'art-standard-lib'
{
  globalCount
  resetGlobalCounts
} = require 'art-foundation'

{eventEpoch}  = eventEpoch  = require('art-events').EventEpoch
{stateEpoch}  = StateEpoch  = require './StateEpoch'
{drawEpoch}   = DrawEpoch   = require './Drawing/DrawEpoch'
{idleEpoch}   = IdleEpoch   = require './IdleEpoch'

ArtFrameStats = require 'art-frame-stats'

# ArtFrameStats
# .registerStatColor #39c     :draw
# .registerStatColor #9c3     :aim    :aimLayout  :aimTL        :aimRR
# .registerStatColor :gold    :react  :reactAim   :reactUpdate  :reactRender
# .registerStatColor #d936a3  :flux
# .registerStatColor #ff6347  :event

# .registerEventColors
#   generateDrawCache:  :green
#   animation:          #77f
#   animationAborted:   #f77
#   animationDone:      #77f
#   default:            :gray

{Epoch} = require 'art-epoched-state'

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

    idleEpoch.queueNextEpoch  =
    stateEpoch.queueNextEpoch =
    drawEpoch.queueNextEpoch  =
    eventEpoch.queueNextEpoch = => @queueNextEpoch()

    # If a pointerClick causes the full global epoch to be processed, frameTime is all wrong for animations.
    # I think it's OK to just push the event-epoch out (which should allow the request-image-dialog to fire)
    # eventEpoch.flushEpochNow  = => @flushEpochNow()

    eventEpoch.logEvent = ArtFrameStats.logEvent # (name, id) => @logEvent name, id

  allowFluxOnIdle: (nextNSeconds)->
    log.warn "DEPRICATED: Art.Engine.GlobalEpochCycle.allowFluxOnIdle - now a noop"

  ############################
  # ArtFrameStats
  ############################
  logEvent:             ArtFrameStats.logEvent
  startTimePerformance: ArtFrameStats.startTimer
  endTimePerformance:   ArtFrameStats.endTimer

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
    @processFluxEpoch()
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

    resetGlobalCounts()

    ArtFrameStats.startFrame()

    @processingCycle = true
    @_processCycleExceptDraw()

    ### Why processStateEpoch twice?
      Animations triggered on element creation cannot be properly initalized until
      all other properties have been applied - i.e. until stateEpoch.onNextReady
      However, animations triggered on element creation need to set their start-state before
      the next redraw. Therefor, we allow a second iteration of non-draw epochs.
      ALSO: some Components need to capture ElementSizes to refine layout (VerticalStackPager), so they may need one extra cycle.
      SBD: Changed on 12-20-2015 to only reprocess StateEpoch. That's all the animators need.
        In particular, I don't want to process the eventEpoch twice since animators trigger their frames
        each time we process the eventEpoch.
        We could process the React epoch again, but we don't need it with the new Art.EngineRemote code
    ###
    @processStateEpoch() if stateEpoch.getEpochLength() > 0

    drawCount = drawEpoch.epochLength
    @processDrawEpoch()
    @processingCycle = false

    if @getEpochLength() > 0
      # console.warn "GlobalEpochCycle: processed maximum state and event cycles (#{@getEpochLength()}) before Draw."
      @queueNextEpoch()

    ArtFrameStats.endFrame()
