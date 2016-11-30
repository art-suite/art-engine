# https://developer.mozilla.org/en-US/docs/Web/HTML/Element/Input

Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
SynchronizedDomOverlay = require "./SynchronizedDomOverlay"

{rgbColor} = Atomic
{createElementFromHtml} = Foundation.Browser.Dom
{TextArea, Input} = Foundation.Browser.DomElementFactories
{log, merge, select, inspect, createWithPostCreate, wordsArray, timeout} = Foundation

module.exports = createWithPostCreate class TextInput extends SynchronizedDomOverlay
  # options
  #   value:      ""
  #   color:      "black"
  #   fontSize:   16 (pixels)
  #   fontFamily: "Arial"
  #   align:      "left"
  #   style:      custom style
  #   padding:    5 (pixels)
  #   maxLength
  #   autoCapitalize
  #   autoComplete
  #   autoCorrect
  # TODO: these need to become ElementProperties that update the DOMElement when changed.
  constructor: (options = {}) ->
    props =
      placeholder:    options.placeholder || ""
      type:           options.type
      # NOTE: moving towards using 100% lowerCamelCase in Art.Engine - even if HTML5's name is full-lower-case
      # SO, these full-lower-case options are depricated (e.g. don't use maxlength, use maxLength)
      maxlength:      options.maxLength       || options.maxlength
      autocapitalize: options.autoCapitalize  || options.autocapitalize
      autocomplete:   options.autoComplete    || options.autocomplete
      autocorrect:    options.autoCorrect     || options.autocorrect

    Factory = if props.type == "textarea"
      delete props.type
      TextArea
    else
      props.type ||= 'text'
      Input

    options.domElement = Factory props,
      options.attrs
      options.style
      value: options.value || ""
      style:
        resize:           "none"
        backgroundColor:  'transparent'
        border:           '0px'
        color:            rgbColor(options.color || "black").toString()
        fontFamily:       options.fontFamily || "Arial"
        fontSize:         "#{options.fontSize || 16}px"
        margin:           "0"
        outline:          "0"
        padding:          "0"
        textAlign:        options.align || "left"
        verticalAlign:    "bottom"
      on:
        keydown:  (keyboardEvent) => @getCanvasElement()?.keyDownEvent keyboardEvent
        keyup:    (keyboardEvent) => @getCanvasElement()?.keyUpEvent keyboardEvent
        change:   (event) => @checkIfValueChanged()
        input:    (event) => @checkIfValueChanged()
        select:   (event) => @queueEvent "selectionChanged"
        focus:    (event) =>
          @_canvasElementToFocusOnBlur = @getCanvasElement()
          @_focus()
        blur:     (event) =>
          # since the Input element is not a child of Canvas, blur won't restore focus to the Canvas
          if @_canvasElementToFocusOnBlur
            # If we are switching focus to another TextInput, document.activeElement won't be updated
            # until AFTER this event is processed. Wait and check in a bit to see if focus really reverted to 'body'.
            timeout 0, =>
              @_canvasElementToFocusOnBlur.focusCanvas() if document.body == document.activeElement

          @_blur()

    super

    @willConsumeKeyboardEvent =
      order: "beforeAncestors"
      allowBrowserDefault: true

    @lastValue = @value

  preprocessEventHandlers: (handlerMap) ->
    merge super,
      focus: => @domElement.focus() unless @domElement.focused
      blur:  => @domElement.blur()  if     @domElement.focused
      keyPress: ({props}) =>
        @handleEvent "enter", value:@value if props.key == "Enter"
        @handleEvent "escape", value:@value if props.key == "Escape"

  _unregister: ->
    @_canvasElementToFocusOnBlur?.focusCanvas()
    super

  checkIfValueChanged: ->
    if @lastValue != @value
      @lastValue = @value
      @queueEvent "valueChanged",
        value: @value
        lastValue: @lastValue

  @virtualProperty
    value:
      getter: (pending) -> @domElement.value
      setter: (v) ->
        v = if v? then "#{v}" else ""
        unless @domElement.value == v
          @domElement.value = v

    color:
      getter: -> rgbColor @domElement.style.color
      setter: (c)->
        self.domElement = @domElement
        @domElement.style.color = rgbColor(c).toString()

  selectAll: ->
    @domElement.select()
