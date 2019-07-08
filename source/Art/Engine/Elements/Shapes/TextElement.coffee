Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Text = require 'art-text'
ShadowableElement = require '../ShadowableElement'

{log, BaseClass, shallowClone, pureMerge, merge, createWithPostCreate, isPlainArray
  isString, isNumber
} = Foundation
{point, rect} = Atomic
{normalizeFontOptions} = Text.Metrics

{startFrameTimer, endFrameTimer} = require 'art-frame-stats'

propInternalName = BaseClass.propInternalName
propSetterName = BaseClass._propSetterName
module.exports = createWithPostCreate class TextElement extends ShadowableElement

  # defaultSize: cs:1

  constructor: ->
    super
    @_textLayout = null

  @getter cacheable: -> true

  @drawLayoutProperty
    fontSize:     default: 16,        validate: (v) -> isNumber v
    fontFamily:   default: "Times",   validate: (v) -> isString v
    fontStyle:    default: "normal",  validate: (v) -> isString v
    fontVariant:  default: "normal",  validate: (v) -> isString v
    fontWeight:   default: "normal",  validate: (v) -> isString v
    align:        default: 0,         preprocess: (v) -> point v
    layoutMode:   default: "textualBaseline",  validate: (v) -> isString v
    leading:      default: 1.25,      validate: (v) -> isNumber v
    paragraphLeading: default: null, validate: (v) -> v == null || isNumber v
    maxLines:     default: null,      validate: (v) -> !v? || isNumber v
    overflow:     default: "ellipsis",  validate: (v) -> isString v

    text:
      default: Text.Layout.defaultText
      preprocess: (t) ->
        if isPlainArray t
          t.join "\n"
        else if t?
          "#{t}"
        else ""

  @virtualProperty
    font:
      getter: (pending) ->
        {_fontFamily, _fontSize, _fontStyle, _fontVariant, _fontWeight} = @getState pending
        fontFamily:   _fontFamily
        fontSize:     _fontSize
        fontStyle:    _fontStyle
        fontVariant:  _fontVariant
        fontWeight:   _fontWeight
    format:
      getter: (pending) ->
        {_align, _layoutMode, _paragraphLeading, _leading, _maxLines, _overflow} = @getState pending
        align:        _align
        layoutMode:   _layoutMode
        leading:      _leading
        paragraphLeading: _paragraphLeading
        maxLines:     _maxLines
        overflow:     _overflow


  @virtualProperty
    preFilteredBaseDrawArea: (pending) ->
      # TODO: this doesn't actually fetch the Pending state.
      @_textLayout?.getDrawArea() || ShadowableElement.preFilteredBaseDrawArea.call @, pending

  nonChildrenLayoutFirstPass: (constrainedSize, unconstrainedSize) ->
    # log TextElement: nonChildrenLayoutFirstPass: {@inspectedName,constrainedSize, unconstrainedSize}
    ret = null
    startFrameTimer "textLayout"
    @_textLayout = new Text.Layout @getPendingText(), @getPendingFont(), @getPendingFormat(), unconstrainedSize.x, unconstrainedSize.y
    ret = @_textLayout.getSize()
    endFrameTimer()
    ret

  nonChildrenLayoutFinalPass: (size) ->
    # log TextElement: nonChildrenLayoutFinalPass: {@inspectedName, size}
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
