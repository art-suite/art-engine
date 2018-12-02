{defineModule, inspect, clone, peek, first, merge, isNumber} = require 'art-standard-lib'
{Event} = require 'art-events'
{Matrix, point, rect, matrix} = require 'art-atomic'

arrayize = (single, array, defaultArray)->
  if single then [single] else array || defaultArray || []

transformedArray = (arrayOfPoints, matrix) ->
  for p in arrayOfPoints
    matrix.transform p

defineModule module, class PointerEvent extends Event
  constructor: (type, pointer, propsOrTime) ->
    props = if isNumber propsOrTime
      log.warn "DEPRICATED: propsOrTime should always be props. Use: 'time: eventTime'"
      time: propsOrTime
    else propsOrTime

    super type, props, props?.time
    @pointer = pointer

  clone: -> @newEvent()

  emptyObject = {}
  newEvent: (options = emptyObject)->
    e = new PointerEvent(
      options.type    ? @type
      options.pointer ? @pointer
      options.time    ? @time
      options.props   ? @props
    )
    e.timeStamp = @timeStamp
    e.target = options.target ? @target
    e

  getAngle = ({currentSize}, {x, y}) ->
    Math.atan2(
      y - currentSize.y / 2
      x - currentSize.x / 2
    )

  getAngleDelta = (a1, a2) ->
    d = (a1 - a2) %% (Math.PI * 2)
    if d > Math.PI
      d - Math.PI * 2
    else
      d

  @getter
    numActivePointers:          -> @pointer.activePointers.length
    activePointers:             -> @pointer.activePointers
    stayedWithinDeadzone:       -> @pointer.stayedWithinDeadzone
    leftDeadzone:               -> !@stayedWithinDeadzone
    location:                   -> @pointer.locationIn @target
    firstLocation:              -> @pointer.firstLocationIn @target
    lastLocation:               -> @pointer.lastLocationIn @target

    # NOTE - angles are taken from the center of @target
    firstAngle:                 -> getAngle @target, @firstLocation
    angle:                      -> getAngle @target, @location
    angleDelta:                 -> getAngleDelta @firstAngle, @angle

    absLocation:                -> @pointer.location
    absFirstLocation:           -> @pointer.firstLocation
    absLastLocation:            -> @pointer.lastLocation

    parentLocation:             -> @pointer.locationIn @target.parent
    parentParentLocation:       -> @pointer.locationIn @target.parent.parent

    parentFirstLocation:        -> @pointer.firstLocationIn @target.parent
    parentParentFirstLocation:  -> @pointer.firstLocationIn @target.parent.parent

    parentLastLocation:         -> @pointer.lastLocationIn @target.parent
    parentParentLastLocation:   -> @pointer.lastLocationIn @target.parent.parent

    absDelta:                   -> @pointer.location.sub @pointer.lastLocation
    delta:                      -> @location.sub @lastLocation
    parentDelta:                -> @pointer.deltaIn @target.parent
    parentParentDelta:          -> @pointer.deltaIn @target.parent.parent

    absTotalDelta:              -> @pointer.location.sub @pointer.firstLocation
    totalDelta:                 -> @location.sub @firstLocation
    totalParentDelta:           -> @pointer.totalDeltaIn @target.parent
    totalParentParentDelta:     -> @pointer.totalDeltaIn @target.parent.parent

    # Multitouch
    locations: ->
      if @activePointers?.length > 1
        for pointer in @activePointers
          pointer.locationIn @target
      else
        [@locationIn]

    firstLocations: ->
      if @activePointers?.length > 1
        for pointer in @activePointers
          pointer.firstLocationIn @target
      else
        [@firstLocation]

    multitouchLeftDeadzone: ->
      if @activePointers?.length > 1
        for p in @activePointers when p.leftDeadzone
          return true
        false
      else @leftDeadzone

    multitouchTransform: ->
      if @activePointers?.length > 1
        [p1, p2] = @activePointers
        Matrix.multitouch(
          p1.firstLocationIn  @target
          p1.locationIn       @target
          p2.firstLocationIn  @target
          p2.locationIn       @target
        )
      else
        Matrix.translate @totalDelta

    multitouchParts: ->
      if @activePointers?.length > 1
        [p1, p2] = @activePointers
        Matrix.multitouchParts(
          p1.firstLocationIn  @target
          p1.locationIn       @target
          p2.firstLocationIn  @target
          p2.locationIn       @target
        )
      else
        translate: @totalDelta
        rotate: 0
        scale:  1


  toElementMatrix: (element) ->
    @target.getElementToElementMatrix(element)

  # locations in element's space
  locationIn:      (element) -> @pointer.locationIn element
  lastLocationIn:  (element) -> @pointer.lastLocationIn element
  firstLocationIn: (element) -> @pointer.firstLocationIn element
