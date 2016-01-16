define [
  'art.foundation'
  'art.atomic'
], (Foundation, Atomic) ->

  {inspect, clone, peek, first, BaseObject} = Foundation
  {point, rect, matrix} = Atomic

  class Pointer extends BaseObject
    # a deadZone of 3 is fine for desktop touchpads and mind AND iOS, but it was terrible on the
    # Samsung Galaxy S6. A deadzone of 10 doesn't seem too much any device and works much better on the Galaxy.
    @pointerDeadZone: pointerDeadZone = 10
    @pointerDeadZoneSquared: pointerDeadZoneSquared = pointerDeadZone * pointerDeadZone

    constructor: (id, location, lastLocation, firstLocation, stayedWithinDeadzone = true)->
      @id = id
      @location = location
      @lastLocation = lastLocation || location
      @firstLocation = firstLocation || location
      @stayedWithinDeadzone = stayedWithinDeadzone

    emptyObject = {}
    newPointer: (options = emptyObject) ->
      new Pointer(
        options.id || @id
        options.location || @location
        options.lastLocation || @lastLocation
        options.firstLocation || @firstLocation
        options.stayedWithinDeadzone || @stayedWithinDeadzone
      )

    moved: (newLocation) ->
      stayedWithinDeadzone = @stayedWithinDeadzone &&
        newLocation.distanceSquared(@firstLocation) <= pointerDeadZoneSquared

      # @log stayedWithinDeadzone:stayedWithinDeadzone, newLocation:newLocation,
      #   distanceFromStart:newLocation.distance(@firstLocation)

      new Pointer @id, newLocation, @location, @firstLocation, stayedWithinDeadzone

    locationIn:      (element) -> if element then element.absToElementMatrix.transform @location else @location
    lastLocationIn:  (element) -> if element then element.absToElementMatrix.transform @lastLocation else @lastLocation
    firstLocationIn: (element) -> if element then element.absToElementMatrix.transform @firstLocation else @firstLocation
    deltaIn:         (element) -> if element then element.absToElementMatrix.transformDifference @location, @lastLocation else @location.sub @lastLocation
    totalDeltaIn:    (element) -> if element then element.absToElementMatrix.transformDifference @location, @firstLocation else @location.sub @firstLocation
