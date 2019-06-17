Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
EngineCore = require '../Core'
{defineModule, log, miniInspect, currentSecond, max, min, timeout, peek} = Foundation
{point, rect, Matrix, rgbColor} = Atomic
{GlobalEpochCycle} = EngineCore
{globalEpochCycle} = GlobalEpochCycle
{floor} = Math

reactColor = rgbColor "gold"
aimColor = rgbColor "#9c3"

defineModule module, ->
  class GlobalEpochStat extends Foundation.BaseClass
    constructor: (@sampleTime, @total, @sampleSet) ->

    @statFields:  statFields  = ["total", "draw", "aim", "aimLayout", "aimTL", "aimRR", "react", "reactAim", "reactUpdate", "reactRender", "event", "flux"]
    @statColors: statColors =
      total:  "gray"
      draw:   "#39c"
      aim:          aimColor
      aimLayout:    aimColor.withLightness aimColor.lightness * .9
      aimTL:        aimColor.withLightness aimColor.lightness * .8
      aimRR:        aimColor.withLightness aimColor.lightness * .7
      react:        reactColor
      reactAim:     reactColor.withLightness reactColor.lightness *.9
      reactUpdate:      reactColor.withLightness reactColor.lightness *.8
      reactRender:  reactColor.withLightness reactColor.lightness *.7
      event:  "#ff6347"
      flux:   "#d936a3"

    getStacked: (sampleName) ->
      return @total if sampleName == "total"
      sum = 0
      for sn in statFields by -1
        sum += @sampleSet[sn] || 0
        break if sn == sampleName
      sum

    drawSample: (bitmap, drawMatrix, sampleWidth, sampleField, h) ->
      {sampleTime} = @
      sample = @getStacked sampleField
      x = floor drawMatrix.transformX sampleTime, sample
      y = floor drawMatrix.transformY sampleTime, sample
      bitmap.drawRectangle null, rect(x, y, sampleWidth, h - y), color: statColors[sampleField]

  class GlobalEpochStats extends Foundation.BaseClass
    @classGetter
      enabled: -> !!globalEpochCycle.globalEpochStats

    @enable: ->
      log "Enabled globalEpochStats"
      globalEpochCycle.globalEpochStats = new @
      true

    @toggle: ->
      if @enabled
        @disable()
      else
        @enable()

    @disable: ->
      log "Disabled globalEpochStats"
      globalEpochCycle.globalEpochStats = null
      false

    constructor: ->
      @reset()

    reset: ->
      @maxMs = 2/60
      @stats = []
      @nextEventIdIndex = 0
      @eventsById = {}
      @eventLegend = {}
      @_minSampleTime = null
      @_maxSampleTime = null

    add: (sampleTime, total, sampleSet) ->
      @stats.push ges = new GlobalEpochStat sampleTime, total, sampleSet

      @maxMs = max @maxMs, total * 1.5
      @logAndResetWhenIdle()
      @addSampleTime sampleTime

    addSampleTime: (time) ->
      @_minSampleTime = min time, @_minSampleTime || time
      @_maxSampleTime = max time, @_maxSampleTime || time

    logEvent: (name, id) ->
      now = currentSecond()
      id ?= name
      @addSampleTime now
      colors =
        generateDrawCache: "green"
        animation: "#77f"
        animationAborted: "#f77"
        animationDone: "#77f"
        default: "gray"

      clr = colors[name] || colors.default

      ebi = @eventsById[id] ||=
        startTime: now
        endTime: now
        index: @nextEventIdIndex++
        events: []
        name:name
        clr: clr

      ebi.startTime = min now, ebi.startTime
      ebi.endTime = max now, ebi.endTime

      @eventLegend[name] = clr

      ebi.events.push
        time: now
        name: name
        clr: clr

    @getter
      minSampleTime: -> @_minSampleTime
      maxSampleTime: -> @_maxSampleTime
      sampleTimeRange: -> @maxSampleTime - @minSampleTime

    drawAllSamplesForOneField: (bitmap, drawMatrix, sampleField) ->
      {size} = bitmap
      {w, h} = size
      {sampleTimeRange, stats} = @
      sampleWidth = floor (w / sampleTimeRange) / 60
      for stat in stats
        stat.drawSample bitmap, drawMatrix, sampleWidth, sampleField, h
      null

    getDrawMatrix: (size)->
        {w, h} = size
        legendWidth = 80
        w -= legendWidth
        {sampleTimeRange, minSampleTime, maxMs} = @
        sampleWidth = floor (w / sampleTimeRange) / 60
        xScale = (w - sampleWidth) / sampleTimeRange
        yScale = h / maxMs
        Matrix.scaleXY(1, -1).translateXY(-minSampleTime, 0).scaleXY(xScale, yScale).translateXY(legendWidth, h)

    drawLabeledHLine: (bitmap, x1, x2, y, clr, label) ->
      bitmap.drawRectangle null, rect(x1, y, x2-x1, 1), color:rgbColor clr
      bitmap.drawText point(x1, y-5), label, size:14, color:rgbColor clr

    drawEvents: (bitmap, drawMatrix) ->
      {w, h} = bitmap.size

      eventTimeLineHeight = floor h / 20
      for id, {index, startTime, endTime, clr, events, name} of @eventsById
        x1 = floor drawMatrix.transformX startTime, 0
        x2 = floor drawMatrix.transformX endTime, 0
        y = (index + 1) * eventTimeLineHeight
        @drawLabeledHLine bitmap, x1, x2, y, clr, name
        for {time, name, clr} in events
          x = floor drawMatrix.transformX time, 0
          bitmap.drawRectangle null, rect(x, y, 1, eventTimeLineHeight * (1/3)), color:clr

    log: ->
      return unless @stats.length > 0

      !Neptune.Art.Foundation.DevTools.DomConsole?.enabled && ce = GlobalEpochCycle.activeCanvasElements[0]

      bitmap = new Canvas.Bitmap size = if ce then ce.canvasBitmap.size else point 1000, 600
      {w, h} = size
      bitmap.clear "#fff"
      drawMatrix = @getDrawMatrix size

      y = floor drawMatrix.transformY 0, 1/60
      tenMsY = floor drawMatrix.transformY 0, 1/100
      fiveMsY = floor drawMatrix.transformY 0, 1/200
      bitmap.drawRectangle null, rect(0, y, w, 1), color:"#0007"

      for sampleField in GlobalEpochStat.statFields
        @drawAllSamplesForOneField bitmap, drawMatrix, sampleField

      legend = {}

      @drawLabeledHLine bitmap, 40, w, tenMsY, "#0007", "10ms"
      @drawLabeledHLine bitmap, 40, w, fiveMsY, "#0007", "5ms"
      @drawEvents bitmap, drawMatrix

      totalFrames = @stats.length
      averageFrameTimeMs = @sampleTimeRange / totalFrames
      perfectFrameCount = @sampleTimeRange * 60 + .5 | 0
      missedFrames = perfectFrameCount - totalFrames
      averageFrameTimeMsY = floor drawMatrix.transformY 0, averageFrameTimeMs
      if (averageFps = 1 / averageFrameTimeMs + .5 | 0) < 55
        @drawLabeledHLine bitmap, 40, w, y, "#0007", "60fps - 16.7ms"
      @drawLabeledHLine bitmap, 40, w, averageFrameTimeMsY, "#0007", "average: #{averageFps}fps (miss-rate: #{(100 * missedFrames / perfectFrameCount).toPrecision(2)}% #{missedFrames}/#{perfectFrameCount})"

      y = 0
      for field in GlobalEpochStat.statFields
        clr = GlobalEpochStat.statColors[field]

        bitmap.drawRectangle null, rect(0, y, 75, 23), color:clr
        bitmap.drawText point(5, y + 18), field, size:16, color:rgbColor "white"
        y += 25


      bitmap.drawBorder null, bitmap.size, "#eee"

      if ce
        log "showing GlobalEpochStats"
        ce.canvasBitmap.drawBitmap null, bitmap, opacity: .9
      else
        log bitmap

    logAndResetWhenIdle: ->
      samples = @stats.length
      if samples > 0
        timeout 1000, =>
          if samples == @stats.length && GlobalEpochStats.enabled
            @log()
            @reset()
