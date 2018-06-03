# https://developer.mozilla.org/en-US/docs/Web/HTML/Element/Input
{defineModule, log, object, merge, select, inspect, wordsArray, timeout, max} = require 'art-standard-lib'
{rgbColor, point} = require 'art-atomic'

Foundation = require 'art-foundation'
{iOSDetect} = Foundation.Browser
{createElementFromHtml} = Foundation.Browser.Dom
{TextArea, Input} = Foundation.Browser.DomElementFactories
SynchronizedDomOverlay = require "./SynchronizedDomOverlay"

defineModule module, class TextInputElement extends SynchronizedDomOverlay
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
  defaultFontSize = 16
  @concreteProperty
    placeholder:  postSetter: (v) -> @domElement?.placeholder = v ? ""
    maxLength:    postSetter: (v) -> @domElement?.maxLength   = v ? null
    fontFamily:   "sans-serif", postSetter: (v) -> @domElement?.fontFamily  = v ? "sans-serif"
    align:
      preprocess: (v) ->
        switch v
          when "left", "center", "right" then v
          when null, undefined then "left"
          else
            {x} = point v
            if x < .25 then "left"
            else if x > .75 then "right"
            else "center"
      postSetter: (v) -> @domElement?.style.textAlign = v

    fontSize:
      validate: (v) -> v > 0
      default: defaultFontSize
      postSetter: (v) -> @domElement?.fontSize    = "#{v || defaultFontSize}px"
    color:        postSetter: (v) -> @domElement?.color       = rgbColor(v || "black").toString()

  normalizeAuto = (v) ->
    if v?
      v || "off"

  constructor: (options = {}) ->
    @_focusEventsDisabled = false
    props = object
      placeholder:    options.placeholder || ""
      type:           options.type
      # NOTE: moving towards using 100% lowerCamelCase in Art.Engine - even if HTML5's name is full-lower-case
      # SO, these full-lower-case options are depricated (e.g. don't use maxlength, use maxLength)
      maxlength:      options.maxLength       || options.maxlength
      autocapitalize: normalizeAuto options.autoCapitalize  ? options.autocapitalize
      autocomplete:   normalizeAuto options.autoComplete    ? options.autocomplete
      autocorrect:    normalizeAuto options.autoCorrect     ? options.autocorrect

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
        fontSize:         "#{options.fontSize || defaultFontSize}px"
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
          if @_safeToProcessFocusEvents()

            @_canvasElementToFocusOnBlur = @getCanvasElement()
            @_focus()

        blur:     (event) =>
          if @_safeToProcessFocusEvents()

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

  # returns childrenSize
  nonChildrenLayoutFirstPass: ->
    point @domElement.scrollWidth,
      max @getPendingFontSize() * 1.4, if @value.length > 0 then @domElement.scrollHeight else 0

  _safeToProcessFocusEvents: ->
    if @_focusEventsDisabled
      false
    else
      @_focusEventsDisabled = true
      timeout 100, => @_focusEventsDisabled = false
      true

  preprocessEventHandlers: (handlerMap) ->
    merge super,
      focus: (event) =>
        if @_safeToProcessFocusEvents()
          @domElement.focus() unless @domElementFocused
          handlerMap.focus? event

      blur:  (event) =>
        if @_safeToProcessFocusEvents()
          @domElement.blur() if @domElementFocused
          handlerMap.blur? event

      keyPress: (e) =>

        handlerMap.keyPress? e
        {props} = e
        @handleEvent "enter",  merge props, value: @value if props.key == "Enter"
        @handleEvent "escape", merge props, value: @value if props.key == "Escape"

  _unregister: ->
    @_canvasElementToFocusOnBlur?.focusCanvas()
    super

  checkIfValueChanged: ->
    if @lastValue != @value
      if @size.childrenRelative
        @_layoutPropertyChanged()
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
          @_elementChanged true
          @lastValue = v
          @domElement.value = v

    color:
      getter: -> rgbColor @domElement.style.color
      setter: (c)->
        self.domElement = @domElement
        @domElement.style.color = rgbColor(c).toString()

  selectAll: ->
    @domElement.select()

  # reference: https://stackoverflow.com/questions/34045777/copy-to-clipboard-using-javascript-in-ios
  copy: ->
    el = @domElement

    if iOSDetect()
      {readOnly, contentEditable} = el

      el.contentEditable  = true
      el.readOnly         = false

      range = document.createRange()
      range.selectNodeContents el

      sel = window.getSelection()

      sel.removeAllRanges()
      sel.addRange          range
      el.setSelectionRange  0, 999999

      result = document.execCommand 'copy'

      el.contentEditable    = contentEditable
      el.readOnly           = readOnly
      sel.removeAllRanges()
      el.blur()

      result
    else
      el.select()
      document.execCommand 'copy'

  insertAtCursor: (insertValue) ->
    log insertAtCursor: {insertValue}
    # //IE support
    # if (document.selection) {
    #     @domElement.focus();
    #     sel = document.selection.createRange();
    #     sel.text = insertValue;
    # }
    # //MOZILLA and others
    if @domElement.selectionStart || @domElement.selectionStart == '0'
      {value, selectionStart, selectionEnd} = @domElement
      log insertAtCursor: {value, selectionStart, selectionEnd,insertValue}
      @domElement.value =
        value.substring(0, selectionStart) + insertValue +
        value.substring selectionEnd, value.length
      @domElement.selectionEnd = @domElement.selectionStart = selectionStart + insertValue.length
    else
      @domElement.value += insertValue
    @checkIfValueChanged()
