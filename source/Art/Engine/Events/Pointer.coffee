{inspect, defineModule, clone, peek, first, log} = require 'art-standard-lib'
{simpleBrowserInfo} = require('art-foundation').Browser
{BaseClass} = require 'art-class-system'
{point, rect, matrix} = require 'art-atomic'

defineModule module, class Pointer extends BaseClass
  ###
  OLD:
    a deadZone of 3 is fine for desktop touchpads and iOS, but it was terrible on the
    Samsung Galaxy S6. A deadzone of 10 doesn't seem too much any device and works much better on the Galaxy.

  NEW:
    NOTES:
      * First, the events are coming in as pixel-locations, not point-locations, so we needed to add getDevicePixelRatio()
      * Second, Android returns fractional locations - not sure why, it's silly.

    Calibrating the DeadZone: (2018-11-15 SBD)
      Testing on: Samsung Galaxy S5
      Methodology:
        If I press my finger down, wiggle it IN PLACE, and let go,
        it should be considered to have "stayedWithinDeadzone"
  ###
  @pointerDeadZone:         pointerDeadZone =
    simpleBrowserInfo.pixelsPerPoint *
      if simpleBrowserInfo.os == "android"
        8
      else
        3

  @pointerDeadZoneSquared:  pointerDeadZoneSquared = pointerDeadZone * pointerDeadZone
  @getter
    activePointers: -> @pointerEventManager.activePointers
    inspectedObjects: ->
      pointer: {
        @id
        @location
        @lastLocation
        @firstLocation
        @stayedWithinDeadzone
      }

  constructor: (@pointerEventManager, id, location, lastLocation, firstLocation, stayedWithinDeadzone = true)->
    @id = id
    @location = location
    @lastLocation = lastLocation || location
    @firstLocation = firstLocation || location
    @stayedWithinDeadzone = stayedWithinDeadzone

  emptyObject = {}
  newPointer: (options = emptyObject) ->
    new Pointer(
      options.pointerEventManager || @pointerEventManager
      options.id || @id
      options.location || @location
      options.lastLocation || @lastLocation
      options.firstLocation || @firstLocation
      options.stayedWithinDeadzone || @stayedWithinDeadzone
    )

  moved: (newLocation) ->
    stayedWithinDeadzone = @stayedWithinDeadzone &&
      newLocation.distanceSquared(@firstLocation) <= pointerDeadZoneSquared

    new Pointer @pointerEventManager, @id, newLocation, @location, @firstLocation, stayedWithinDeadzone

  locationIn:      (element) -> if element then element.absToElementMatrix.transform @location else @location
  lastLocationIn:  (element) -> if element then element.absToElementMatrix.transform @lastLocation else @lastLocation
  firstLocationIn: (element) -> if element then element.absToElementMatrix.transform @firstLocation else @firstLocation
  deltaIn:         (element) -> if element then element.absToElementMatrix.transformDifference @location, @lastLocation else @location.sub @lastLocation
  totalDeltaIn:    (element) -> if element then element.absToElementMatrix.transformDifference @location, @firstLocation else @location.sub @firstLocation
  @getter
    totalDelta: -> @location.sub @firstLocation