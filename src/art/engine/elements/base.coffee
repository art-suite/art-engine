define [
  'art-foundation'
  'art-atomic'
  '../core/element'
], (Foundation, Atomic, Element) ->
  {inspect, createWithPostCreate} = Foundation
  {color} = Atomic

  createWithPostCreate class Base extends Element
    @registerWithElementFactory: -> @ != Base

    constructor: ->
      super
      @_drawOptions = {}

    @drawProperty color: default: null, preprocess: (v) -> if v then color v else null

    #############
    # OVERRIDES
    #############
    drawBasic: (target, elementToTargetMatrix, compositeMode, opacity) ->
      @_prepareDrawOptions compositeMode, opacity
      @fillShape target, elementToTargetMatrix, @_drawOptions

    _useStagingBitmap: ->
      return super if @getHasChildren()
      @getChildRequiresParentStagingBitmap() || @getIsMask()

    _drawChildren: (target, elementToTargetMatrix, usingStagingBitmap) ->
      return super if @hasChildren
      if usingStagingBitmap
        @drawBasic target, elementToTargetMatrix
      else
        @drawBasic target, elementToTargetMatrix, @getCompositeMode(), @getOpacity()

    ###
    Either fillShape or drawBasic must be overridden by each inheriting class
    ###
    fillShape: (target, elementToTargetMatrix, options) ->
      throw new Error "fillShape or drawBasic must be overridden"

    ###
    _prepareDrawOptions
    Inheriting classes can override & extend to add additional options
    purpose: to re-use the plain-object for draw options instead of creating a new one every time.
    ###
    _prepareDrawOptions: (compositeMode, opacity)->
      @_drawOptions.compositeMode = compositeMode
      @_drawOptions.opacity       = opacity
      @_drawOptions.color         = @_color
