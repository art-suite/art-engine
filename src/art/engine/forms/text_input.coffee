# https://developer.mozilla.org/en-US/docs/Web/HTML/Element/Input

Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
SynchronizedDomOverlay = require "./synchronized_dom_overlay"

{color} = Atomic
{createElementFromHtml} = Foundation.Browser.Dom
{TextArea, Input} = Foundation.Browser.DomElementFactories
{log, merge, select, inspect, createWithPostCreate} = Foundation

module.exports = createWithPostCreate class TextInput extends SynchronizedDomOverlay
  # options
  #   value:      ""
  #   color:      "black"
  #   fontSize:   16 (pixels)
  #   fontFamily: "Arial"
  #   align:      "left"
  #   style:      custom style
  #   padding:    5 (pixels)
  #   attrs:      - any other input attrs you want to specify such as:
  #     maxlength:  10
  constructor: (options = {}) ->
    props = select options, "placeholder", "type", "autocapitalize", "autocomplete", "autocorrect", "maxlength"
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
        backgroundColor:  'transparent'
        border:           '0px'
        color:            color(options.color || "black").toString()
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
          log "text input focus"
          @_canvasElementToFocusOnBlur = @getCanvasElement()
          @_focus()
        blur:     (event) =>
          # since the Input element is not a child of Canvas, blur won't restore focus to the Canvas
          @_canvasElementToFocusOnBlur?.focusCanvas() if document.body == document.activeElement
          @_blur()

    super

    @lastValue = @value

  preprocessEventHandlers: (handlerMap) ->
    merge super,
      focus: => @domElement.focus()
      blur:  => @domElement.blur()
      keyPress: ({props}) =>
        if props.key == "Enter"
          @handleEvent "enter", value:@value

  checkIfValueChanged: ->
    if @lastValue != @value
      @lastValue = @value
      @queueEvent "valueChanged",
        value: @value
        lastValue: @lastValue

  @virtualProperty
    value:
      getter: (pending) -> @domElement.value
      setter: (v) -> @domElement.value = v

    color:
      getter: -> color @domElement.style.color
      setter: (c)->
        self.domElement = @domElement
        @domElement.style.color = color(c).toString()

  selectAll: ->
    @domElement.select()
