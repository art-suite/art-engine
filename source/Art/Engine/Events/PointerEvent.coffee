Atomic = require 'art-atomic'
Foundation = require 'art-foundation'
Events = require 'art-events'

{point, rect, matrix} = Atomic
{defineModule, inspect, clone, peek, first, merge} = Foundation

arrayize = (single, array, defaultArray)->
  if single then [single] else array || defaultArray || []

transformedArray = (arrayOfPoints, matrix) ->
  for p in arrayOfPoints
    matrix.transform p

defineModule module, class PointerEvent extends Events.Event
  constructor: (type, pointer, time, props) ->
    super type, props, time
    @pointer = pointer

  clone: -> @newEvent()

  emptyObject = {}
  newEvent: (options = emptyObject)->
    e = new PointerEvent(
      options.type    ? @type
      options.pointer ? @pointer
      options.time    ? @time
    )
    e.timeStamp = @timeStamp
    e.target = options.target ? @target
    e

  @getter
    location:                  -> @pointer.locationIn @target
    firstLocation:             -> @pointer.firstLocationIn @target
    lastLocation:              -> @pointer.lastLocationIn @target

    absLocation:               -> @pointer.location
    absFirstLocation:          -> @pointer.firstLocation
    absLastLocation:           -> @pointer.lastLocation

    parentLocation:            -> @pointer.locationIn @target.parent
    parentParentLocation:      -> @pointer.locationIn @target.parent.parent

    parentFirstLocation:       -> @pointer.firstLocationIn @target.parent
    parentParentFirstLocation: -> @pointer.firstLocationIn @target.parent.parent

    parentLastLocation:        -> @pointer.lastLocationIn @target.parent
    parentParentLastLocation:  -> @pointer.lastLocationIn @target.parent.parent

    absDelta:                  -> @pointer.location.sub @pointer.lastLocation
    delta:                     -> @location.sub @lastLocation
    parentDelta:               -> @pointer.deltaIn @target.parent
    parentParentDelta:         -> @pointer.deltaIn @target.parent.parent

    absTotalDelta:             -> @pointer.location.sub @pointer.firstLocation
    totalDelta:                -> @location.sub @firstLocation
    totalParentDelta:          -> @pointer.totalDeltaIn @target.parent
    totalParentParentDelta:    -> @pointer.totalDeltaIn @target.parent.parent

  toElementMatrix: (element) ->
    @target.getElementToElementMatrix(element)

  # locations in element's space
  locationIn:      (element) -> @pointer.locationIn element
  lastLocationIn:  (element) -> @pointer.lastLocationIn element
  firstLocationIn: (element) -> @pointer.firstLocationIn element
