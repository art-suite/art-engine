# https://developer.mozilla.org/en-US/docs/Web/HTML/Element/Input

define [
  'jquery'
  'art.foundation'
  'art.atomic'
  "./synchronized_dom_overlay"
], ($, Foundation, Atomic, SynchronizedDomOverlay) ->
  {color} = Atomic
  {merge, select, inspect, createWithPostCreate} = Foundation

  createWithPostCreate class TextInput extends SynchronizedDomOverlay
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
      props = select options, "placeholder", "type", "autocapitalize", "autocomplete", "autocorrect"
      tagType = if props.type == "textarea"
        delete props.type
        "textarea"
      else
        props.type ||= 'text'
        "input"

      propsString = (for k, v of props
        "#{k}=#{inspect v}"
      ).join " "
      options.domElement = $("<#{tagType} #{propsString}'></input>").val(options.value || "").css merge options.style,
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

      if options.attrs
        for k,v of options.attrs
          options.domElement.attr k, v
      super

      @lastValue = @value
      @domElement.change (event) => @checkIfValueChanged()
      @domElement.on 'input', (event) => @checkIfValueChanged()
      @domElement.select (event) => @queueEvent "selectionChanged"
      @domElement.blur   (event) => @blur()
      @domElement.focus  (event) => @focus()

    preprocessEventHandlers: (handlerMap) ->
      merge super,
        focus: => @domElement.focus()
        blur:  => @domElement.blur()
        keyUp: (e) =>
          if e.key == "enter"
            @handleEvent "enter", value:@value

    checkIfValueChanged: ->
      if @lastValue != @value
        @lastValue = @value
        @queueEvent "valueChanged",
          value: @value
          lastValue: @lastValue

    @getter
      value: -> @domElement.val()
      color: -> color @domElement.css "color"

    @setter
      value: (v)-> @domElement.val(v)
      color: (c)-> @domElement.css "color", c

    selectAll: ->
      @domElement.select()
