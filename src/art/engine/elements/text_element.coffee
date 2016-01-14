# https://developer.mozilla.org/en-US/docs/Web/API/TextMetrics

define [
  '../../foundation'
  '../../atomic'
  '../../text'
  './base'
  '../core/global_epoch_cycle'
], (Foundation, Atomic, Text, Base, GlobalEpochCycle) ->
  {log, BaseObject, shallowClone, pureMerge, merge, createWithPostCreate} = Foundation
  {color, Color, point, Point, rect, Rectangle, matrix, Matrix} = Atomic
  {normalizeFontOptions} = Text.Metrics

  {globalEpochCycle} = GlobalEpochCycle

  propInternalName = BaseObject._propInternalName
  propSetterName = BaseObject._propSetterName

# Proposed layout modes:
#   "artistic" - "tight" - boundaries of text exactly hits the edges of @size
#   "paragraph" - @fontSize is used, text may or maynot fit
#      "alwaysFit" - constantly scale @fontSize to fit whatever @size is - at least the left&right or top&bottom are touched
#      "overflow:Fit" - if the text doesn't fit, then scale @fontSize back
#      "overflow:..." - truncate the text with "..." if it doesn't fit
#      alignment: l/r/c/j
#      wordwrap: t/f

  createWithPostCreate class TextElement extends Base

    defaultSize: cs:1

    constructor: ->
      super
      @_textLayout = null

    # create the normal ElementBase Property using the definePropertyFunctionName,
    # then also create a virtual function for getting and setting every field of the default object.
    @propertySet: (set) ->
      for setName, setOptions of set
        do (setName, setOptions) =>
          definePropertyFunctionName = setOptions.definePropertyFunctionName
          propDefinition = {}
          propDefault = setOptions.default || {}
          propDefinition[setName] =
            default: setOptions.default
            preprocess: setOptions.preprocess
            validate:   setOptions.validate
          @[definePropertyFunctionName] propDefinition
          internalName = propInternalName setName

          setSetterName = propSetterName setName

          virtualProperties = {}
          for subPropName, defaultValue of setOptions.default
            do (subPropName) =>
              virtualProperties[subPropName] =
                getter: (o) -> @[internalName]?[subPropName]
                setter: (v) ->
                  if (oldOptions = @[internalName]) == (newOptions = @_pendingState[internalName])
                    newOptions = shallowClone oldOptions
                    newOptions[subPropName] = v
                    @[setSetterName] newOptions
                  else
                    newOptions[subPropName] = v

          @virtualProperty virtualProperties

    validLayoutModes = Text.Layout.validLayoutOptions.layoutMode
    validOverflows = Text.Layout.validLayoutOptions.overflow
    @propertySet
      font:
        definePropertyFunctionName: "drawLayoutProperty"
        preprocess: (v) -> normalizeFontOptions v
        default: Text.Metrics.defaultFontOptions

      format:
        definePropertyFunctionName: "drawLayoutProperty"
        default: Text.Layout.defaultLayoutOptions
        validate: (layoutOptions) ->
          {layoutMode, overflow} = layoutOptions
          (!layoutMode || validLayoutModes[layoutMode]) &&
          (!overflow   || validOverflows[overflow])

    @drawLayoutProperty
      text:           default: Text.Layout.defaultText, preprocess: (t) -> ""+t
      fontOptions:    validate: (v)-> !v
      layoutOptions:  validate: (v)-> !v

    getBaseDrawArea: ->
      @_textLayout?.getDrawArea() || rect()

    getPendingBaseDrawArea: ->
      # TODO: this doesn't actually fetch the Pending state.
      @_textLayout?.getDrawArea() || rect()

    customLayoutChildrenFirstPass: (size) ->
      ret = null
      globalEpochCycle.timePerformance "aimTL", =>
        @_textLayout = new Text.Layout @getPendingText(), @getPendingFont(), @getPendingFormat(), size.x, size.y
        ret = @_textLayout.getSize()
      ret

    customLayoutChildrenSecondPass: (size) ->
      @_textLayout.setWidth size.x
      @_textLayout.size

    fillShape: (target, elementToTargetMatrix, options) ->
      @_textLayout.draw target, elementToTargetMatrix, pureMerge options,
        layoutSize: @getCurrentSize()
        color:  options?.color || @_color

    strokeShape: (target, elementToTargetMatrix, options) ->
      @_textLayout.stroke target, elementToTargetMatrix, pureMerge options,
        layoutSize: @getCurrentSize()
        color:  options?.color || @_color
