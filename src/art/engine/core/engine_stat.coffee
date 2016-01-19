define [
  'art-foundation'
], (Foundation) ->
  {log, Map, miniInspect, currentSecond, arrayWithout, BaseObject, Stat} = Foundation

  class EngineStat extends BaseObject
    constructor: ->
      @reset()

    reset: -> @stats = {}
    add: (statName, value) ->
      (@stats[statName] ||= new Stat).add value

    length: (statName) ->
      if stat = @stats[statName]
        stat.length
      else
        0

    log: ->
      toLog = {}
      for k, v of @stats
        # a is set to the
        greatestPow10LessThanMax = Math.pow 10, Math.floor Math.log10 v.max
        smallestMultipleGreaterThanMax = (Math.ceil v.max / greatestPow10LessThanMax) * greatestPow10LessThanMax
        toLog[k] =
          min:  v.min.toPrecision(5) / 1
          av:   v.average.toPrecision(5) / 1
          max:  v.max.toPrecision(5) / 1
          hist: v.histogram 10, 0, smallestMultipleGreaterThanMax
          histMax: smallestMultipleGreaterThanMax

      log toLog
