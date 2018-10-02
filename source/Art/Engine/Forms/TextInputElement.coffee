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
    else "off"

  logEventErrors = (handlerMap) ->
    object handlerMap, (handler, eventName) ->
      (event) ->
        try
          out = handler event
          # log "TextInputElement #{eventName}: error-free!"
          out
        catch error
          log.error
            message:  "Error in TextInputElement handler: #{eventName}"
            error:    error
          null

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
        overflow:         "hidden"
      on: logEventErrors
        cut:      (keyboardEvent) => @delayedCheckIfValueChanged()
        paste:    (keyboardEvent) => @delayedCheckIfValueChanged()
        drop:     (keyboardEvent) => @delayedCheckIfValueChanged()
        keydown:  (keyboardEvent) => @delayedCheckIfValueChanged();@getCanvasElement()?.keyDownEvent keyboardEvent
        keyup:    (keyboardEvent) => @getCanvasElement()?.keyUpEvent keyboardEvent
        change:   (event) => @checkIfValueChanged()
        input:    (event) => @checkIfValueChanged()
        select:   (event) => @queueEvent "selectionChanged"
        focus:    (event) =>
          # log "focus 1"
          if @_safeToProcessFocusEvents()
            # log "focus 2.1"
            @scrollOnScreen()
            # log "focus 2.2"

            @_canvasElementToFocusOnBlur = @getCanvasElement()
            # log "focus 3"
            @_focus()

        blur:     (event) =>
          # log "TextInputElement dom blur event 1"
          if @_safeToProcessFocusEvents()
            # log "blur 2"

            # since the Input element is not a child of Canvas, blur won't restore focus to the Canvas
            if @_canvasElementToFocusOnBlur
              # If we are switching focus to another TextInput, document.activeElement won't be updated
              # until AFTER this event is processed. Wait and check in a bit to see if focus really reverted to 'body'.
              # log "blur 3"
              timeout 0, =>
                # log "blur 4"
                @_canvasElementToFocusOnBlur.focusCanvas() if document.body == document.activeElement

            @_blur()

            timeout 100, =>
              try
                # log "TextInputElement dom blur event - AfterBlur"
                # log "AfterBlur 1 #{@focused} - #{(e.inspectedName for e in @canvasElement.focusPath).join ', '}"
                if @canvasElement?.focusedElement == @
                  # log "AfterBlur 2"
                  @canvasElement._saveFocus() if !@focused
                  @canvasElement.blurElement()
                # log "AfterBlur 3"
              catch error
                log TextInputElement: blurHandler: {error}

    super

    @willConsumeKeyboardEvent =
      order: "beforeAncestors"
      allowBrowserDefault: true

    @lastValue = @value

  # Reference: https://stackoverflow.com/questions/454202/creating-a-textarea-with-auto-resize
  # returns childrenSize
  nonChildrenLayoutFirstPass: ->
    point @domElement.scrollWidth,
      max @getPendingFontSize() * 1.4, if @value.length > 0
        @domElement.style.height = '0'
        @domElement.scrollHeight
      else 0

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
        # log "TextInputElement ArtEngine focus event 1. _focusEventsDisabled: #{@_focusEventsDisabled}"
        if true # @_safeToProcessFocusEvents()
          # log "TextInputElement ArtEngine focus event 2 - have handler: #{!!handlerMap.focus}"
          @domElement.focus() unless @domElementFocused
          handlerMap.focus? event
          # log "TextInputElement ArtEngine focus event 3"

      blur:  (event) =>
        # log "TextInputElement ArtEngine blur event 1. _focusEventsDisabled: #{@_focusEventsDisabled}"
        if true # @_safeToProcessFocusEvents()
          # log "TextInputElement ArtEngine blur event 2 - have handler: #{!!handlerMap.blur}"
          @domElement.blur() if @domElementFocused
          handlerMap.blur? event
          # log "TextInputElement ArtEngine blur event 3"

      keyPress: (e) =>

        handlerMap.keyPress? e
        {props} = e
        @handleEvent "enter",  merge props, value: @value if props.key == "Enter"
        @handleEvent "escape", merge props, value: @value if props.key == "Escape"

  _unregister: ->
    @_canvasElementToFocusOnBlur?.focusCanvas()
    super

  delayedCheckIfValueChanged: ->
    timeout 0, => @checkIfValueChanged()

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

  @getter
    selectionStart: -> @domElement.selectionStart
    selectionEnd: -> @domElement.selectionEnd

  @setter
    selectionStart: (v)-> @domElement.selectionStart = v
    selectionEnd: (v)-> @domElement.selectionEnd = v

  insertAtCursor: (insertValue) ->
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
