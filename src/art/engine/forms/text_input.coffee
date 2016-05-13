# https://developer.mozilla.org/en-US/docs/Web/HTML/Element/Input

Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
SynchronizedDomOverlay = require "./synchronized_dom_overlay"

{color} = Atomic
{createElementFromHtml} = Foundation.Browser.Dom
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
    tagType = if props.type == "textarea"
      delete props.type
      "textarea"
    else
      props.type ||= 'text'
      "input"

    propsString = (for k, v of props
      "#{k}=#{inspect v}"
    ).join " "
    options.domElement = el = createElementFromHtml("<#{tagType} #{propsString}'></input>")
    el.value = options.value || ""
    style = merge options.style,
      padding: "#{options.padding || 5}px"
      border: '0px'
      color: color(options.color || "black").toString()
      padding: "0"
      margin: "0"
      "vertical-align": "bottom"
      'text-align': options.align || "left"
      'font-size': "#{options.fontSize || 16}px"
      'background-color': 'transparent'
      'font-family': options.fontFamily || "Arial"
    for k, v of style
      el.style[k] = v

    if options.attrs
      for k,v of options.attrs
        options.domElement.attr k, v
    super

    @lastValue = @value

    @_addKeyboardEventListeners()

    @domElement.onchange = (event) => @checkIfValueChanged()
    @domElement.oninput  = (event) => @checkIfValueChanged()
    @domElement.onselect = (event) => @queueEvent "selectionChanged"
    @domElement.onblur   = (event) =>
      # since the Input element is not a child of Canvas, blur won't restore focus to the Canvas
      @getCanvasElement()?.focusCanvas() if document.body == document.activeElement
      @_blur()

    @domElement.onfocus  = (event) => @_focus()

  _addKeyboardEventListeners: ->
    @domElement.addEventListener "keydown", (keyboardEvent) => @getCanvasElement()?.keyDownEvent keyboardEvent
    @domElement.addEventListener "keyup",   (keyboardEvent) => @getCanvasElement()?.keyUpEvent keyboardEvent

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
