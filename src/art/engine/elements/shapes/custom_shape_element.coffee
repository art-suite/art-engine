define [
  'art.foundation'
  'art.atomic'
  'art.canvas'
  '../fillable_base'
], (Foundation, Atomic, {Paths}, FillableBase) ->
  {pureMerge, isFunction, createWithPostCreate} = Foundation

  createWithPostCreate class CustomShapeElement extends FillableBase

    constructor: ->
      super
      @_lastPathFunction = null
      @_curriedPathFunction = null

    @drawProperty
      fillRule: default: "nonzero", validate: (r) -> r == "nonzero" || r == "evenodd"

      path:
        default: (context, size) ->
          # example path (a rectangle)
          {w, h} = size
          context.beginPath()
          context.moveTo 0, 0
          conext.lineTo 0, h
          conext.lineTo w, h
          conext.lineTo w, 0
          conext.lineTo 0, 0
          context.closePath()

        validate: (f) -> isFunction f

    @getter
      curriedPathFunction: ->
        pathFunction = @getPath()
        if @_lastPathFunction != pathFunction
          @_lastPathFunction = pathFunction
          @_curriedPathFunction = (context) => pathFunction context, @currentSize
        else
          @_curriedPathFunction

    drawBasic: (target, elementToTargetMatrix, compositeMode, opacity) ->
      @_prepareDrawOptions compositeMode, opacity
      @fillShape target, elementToTargetMatrix, @_drawOptions

    # override so Outline child can be "filled"
    fillShape: (target, elementToTargetMatrix, options) ->
      options.color ||= @_color
      options.fillRule = @_fillRule
      target.fillShape elementToTargetMatrix, options, @getCurriedPathFunction()

    # override so Outline child can draw the outline
    strokeShape: (target, elementToTargetMatrix, options) ->
      options.color ||= @_color
      target.strokeShape elementToTargetMatrix, options, @getCurriedPathFunction()
