Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Element = require '../core/element'
{inspect, createWithPostCreate} = Foundation
{color} = Atomic

module.exports = createWithPostCreate class Base extends Element
  @registerWithElementFactory: -> @ != Base

  constructor: ->
    super
    @_drawOptions = {}

  @drawProperty color: default: null, preprocess: (v) -> if v then color v else null

  #############
  # OVERRIDES
  #############
  drawBasic: (target, elementToTargetMatrix, compositeMode, opacity) ->
    @_prepareDrawOptions @_drawOptions, compositeMode, opacity
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
  _prepareDrawOptions: (drawOptions, compositeMode, opacity)->
    drawOptions.compositeMode = compositeMode
    drawOptions.opacity       = opacity
    drawOptions.color         = @_color
