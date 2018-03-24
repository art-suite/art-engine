Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'
Helper = require '../Helper'
StateEpochTestHelper = require '../../Core/StateEpochTestHelper'

{defineModule, inspect, log, min, isNumber, isPlainObject, merge} = Foundation
{point, matrix, Matrix, Point, rect, point1} = Atomic
{Element, RectangleElement, FillElement, TextElement, Shapes} = Engine
{drawTest, drawTest2, drawTest3} =  Helper
{pow} = Math

{stateEpochTest, renderTest} = StateEpochTestHelper

isWithinTest = (correctValue) ->
  isPlainObject(correctValue) && correctValue.max && correctValue.min && Object.keys(correctValue).length == 2

layoutFragmentTester = (element, result) ->
  for areaPart, correctValue of result
    testValue = for {alignedLayoutArea} in element._textLayout.fragments
      Math.round alignedLayoutArea[areaPart]
    note = "testing: element._textLayout.fragments.alignedLayoutArea.#{areaPart}"

    if isWithinTest correctValue
      assert.within testValue, correctValue.min, correctValue.max, note
    else
      assert.eq testValue, correctValue, note

roundedEq = (testValue, correctValue, note) ->
  if (testValue instanceof Atomic.Rectangle) || (testValue instanceof Point)
    testValue = testValue.rounded
  else if isNumber testValue
    Math.round testValue
  if isWithinTest correctValue
    assert.within testValue, correctValue.min, correctValue.max, note
  else
    assert.eq testValue, correctValue, note

layoutTester = (element, tests) ->
  {fragments} = tests
  fragments && layoutFragmentTester element, fragments
  if tests.element
    for k, correctValue of tests.element
      roundedEq  element[k], correctValue, "testing: element.#{k}"
  for k, correctValue of tests when k != "fragments" && k != "element"
    testValue = element._textLayout[k]
    roundedEq testValue, correctValue, "testing: element._textLayout.#{k}"

defineModule module, suite:
  basics: ->
    stateEpochTest "Layout basic", ->
      textElement = new TextElement size: "childrenSize", text:"foo"
      ->
        assert.eq textElement.currentSize.rounded, point 21, 12
        textElement.setText "foobar"
        ->
          assert.eq textElement.currentSize.rounded, point 42, 12

    stateEpochTest "Layout textualBaseline", ->
      textElement = new TextElement size: "childrenSize", text:"foo", layoutMode: "textualBaseline"
      ->
        assert.eq textElement.currentSize.rounded, point 21, 12
        textElement.setText "foobar"
        ->
          assert.eq textElement.currentSize.rounded, point 42, 12

    stateEpochTest "Layout with axis: .5 (basic)", ->
      textElement = new TextElement size: "childrenSize", text:"foo", axis: .5, location: 123
      ->
        assert.eq textElement.currentLocation, point 123, 123
        textElement.setText "foobar"
        ->
          assert.eq textElement.currentLocation, point 123, 123

    stateEpochTest "Layout with axis: .5, location: ps:.5", ->
      new Element size: 246,
        textElement = new TextElement size: "childrenSize", text:"foo", axis: .5, location: ps:.5
      ->
        assert.eq textElement.currentLocation, point 123, 123
        assert.eq textElement.currentSize.rounded, point 21, 12
        textElement.setText "foobar"
        ->
          assert.eq textElement.currentLocation, point 123, 123
          assert.eq textElement.currentSize.rounded, point 42, 12

    drawTest3 "TEXT layoutMode: textual",
      stagingBitmapsCreateShouldBe: 0
      element: ->
        new TextElement
          color:"red", text:"Thing()", fontSize:48
          new RectangleElement color: "#0003"
          new FillElement()

    drawTest3 "layoutMode: textualBaseline",
      stagingBitmapsCreateShouldBe: 0
      element: ->
        new TextElement
          color:"red"
          text:"Thing()\nThang"
          fontSize:48
          layoutMode: "textualBaseline"
          new RectangleElement color: "#0003"
          new FillElement()

    drawTest3 "layoutMode: textualBaseline with word-wrap",
      stagingBitmapsCreateShouldBe: 0
      element: ->
        new TextElement
          size:
            w: (ps, cs) -> min 100, cs.w
            hch:1
          color:"red"
          text:"I am a dog."
          fontSize:32
          layoutMode: "textualBaseline"
          new RectangleElement color: "#0003"
          new FillElement()

    drawTest3 "compositeMode",
      stagingBitmapsCreateShouldBe: 1
      element: ->
        new Element {},
          new RectangleElement size: {w: 40, h: 60}, color:"red"
          new RectangleElement size: {w: 40, h: 60}, location:point(40,0), color:"blue"
          new TextElement color:"#0f0", fontSize:50, text:"test", compositeMode:"add"

    drawTest3 "opacity",
      stagingBitmapsCreateShouldBe: 0
      element: ->
        new TextElement color:"red", fontSize:50, text:"test", opacity:.5

    drawTest3 "all options",
      stagingBitmapsCreateShouldBe: 0
      element: ->
        new TextElement
          color:      "green"
          text:       "Dude!"
          fontSize:   40
          fontFamily: "Times New Roman"
          fontWeight: "bold"
          fontStyle: "italic"
          fontVariant:"small-caps"
          layoutMode: "tight"
          align:      "center"

    drawTest3 "children",
      stagingBitmapsCreateShouldBe: 0
      element: ->
        new TextElement color:"red", fontSize:50, text:"test",
          new FillElement
          new RectangleElement
            color:"#70F7"
            axis:point(.5)
            location: ps: .5
            size: w:60, h:60
            angle: Math.PI * .3

    drawTest3 "children with mask",
      stagingBitmapsCreateShouldBe: 2
      element: ->
        new TextElement color:"red", fontSize:50, text:"test",
          new RectangleElement
            color:"#F0F"
            axis: .5
            location: ps: .5
            size: w:60, h:60
            angle: Math.PI * .3
          new FillElement isMask:true

    drawTest3 "basic",
      stagingBitmapsCreateShouldBe: 0
      element: ->
        new Element
          size: w:100, hch:1
          new RectangleElement color: "#fcc"
          new TextElement color:"red", text:"That darn quick, brown fox. He always gets away!", fontSize:16, size: wpw:1

    drawTest3 "centered-aligned",
      stagingBitmapsCreateShouldBe: 0
      element: ->
        new Element
          size: w:100, hch:1
          new RectangleElement color: "#fcc"
          new TextElement color:"red", text:"That!", fontSize:16, align: "center", size: wpw:1

    drawTest3 "right-aligned",
      stagingBitmapsCreateShouldBe: 0
      element: ->
        new Element
          size: w:100, hch:1
          new RectangleElement color: "#fcc"
          new TextElement color:"red", text:"That!", fontSize:16, align: "right", size: wpw:1

    test "flow two paragraphTexts", ->
      e = new Element
        size: w:200, hch:1
        childrenLayout: "flow"
        e1 = new TextElement color:"red", size:"childrenSize", text:"This is going to be great, don't you think?", fontSize:32
        e2 = new TextElement color:"red", size:"childrenSize", text:"-------", fontSize:32
      e1.onNextReady()
      .then ->
        e.toBitmapBasic {}
      .then (bitmap) ->
        log bitmap
        assert.neq e1.currentLocation, e2.currentLocation

    test "drawArea", ->
      el = new TextElement size: "childrenSize", text:"hi", fontSize:16, align: "center", size: w:300
      el.onNextReady ->
        assert.within el.elementSpaceDrawArea.right, 150, 300

    test "drawArea width wordWrap", ->
      el =
        new Element
          size: w:100, hch:1
          new TextElement
            text:"The quick brown fox jumped over the lazy dog."
            size: wpw:1, hch:1
      el.onNextReady ->
        log el.elementSpaceDrawArea
        el.logBitmap()
        assert.within el.elementSpaceDrawArea.width, 90, 100
        assert.within el.elementSpaceDrawArea.height, 85, 100

  "as shape": ->
    drawTest3 "gradient",
      element: ->
        new TextElement
          colors: ["red", "yellow"]
          text: "Red-yellow gradient."
          fontSize: 32

    drawTest3 "shadow",
      element: ->
        new TextElement
          color: "red"
          shadow: blur: 2, color: "#0005", offset: y: 2
          text: "Shadow"
          fontSize: 32

  alignment:
    "multi-line, layoutMode: textual":

      "layout ps:1": ->
        leftAligned     = [0,   0,    0,    0   ]
        topAligned      = [0,   20,   40,   60  ]
        rightAligned    = [100, 100,  100,  100 ]
        bottomAligned   = [40,  60,   80,   100 ]
        hCenterAligned  = [50,  50,   50,   50  ]
        vCenterAligned  = [20,  40,   60,   80  ]
        for value, result of {
            top:
              area:
                min: rect 0, 0, 82, 72
                max: rect 0, 0, 83, 72
              drawArea:
                min: rect -8, -8, 98, 92
                max: rect -8, -8, 99, 92
              element:
                logicalArea:            rect 0, 0, 100, 100
                elementSpaceDrawArea:
                  min: rect -8, -8, 98, 92
                  max: rect -8, -8, 99, 92
              fragments:             top:      topAligned,     left:     leftAligned
            left:         fragments: top:      topAligned,     left:     leftAligned
            center:       fragments: top:      topAligned,     hCenter:  hCenterAligned
            right:        fragments: top:      topAligned,     right:    rightAligned
            bottom:       fragments: bottom:   bottomAligned,  left:     leftAligned
            topLeft:      fragments: top:      topAligned,     left:     leftAligned
            topCenter:    fragments: top:      topAligned,     hCenter:  hCenterAligned
            topRight:     fragments: top:      topAligned,     right:    rightAligned
            centerLeft:   fragments: vCenter:  vCenterAligned, left:     leftAligned
            centerCenter:
              area:
                min: rect 0, 0, 82, 72
                max: rect 0, 0, 83, 72
              drawArea:
                min: rect 1, 6, 98, 92
                max: rect 1, 6, 99, 92
              fragments:             vCenter:  vCenterAligned, hCenter:  hCenterAligned
            centerRight:  fragments: vCenter:  vCenterAligned, right:    rightAligned
            bottomLeft:   fragments: bottom:   bottomAligned,  left:     leftAligned
            bottomCenter: fragments: bottom:   bottomAligned,  hCenter:  hCenterAligned
            bottomRight:
              area:
                min: rect 0, 0, 82, 72
                max: rect 0, 0, 83, 72
              drawArea:
                min: rect 9,  20, 98, 92
                max: rect 10, 20, 99, 92
              fragments:             bottom:   bottomAligned,  right:    rightAligned
            }
          do (value, result) =>
            drawTest3 "align: '#{value}'",
              stagingBitmapsCreateShouldBe: 0
              element: ->
                new TextElement
                  size: pts: 100
                  align: value
                  color:"red", text:"The quick brown fox jumped over the lazy dog.", fontSize:16
              test: (element) -> layoutTester element, result

      "drawAreas, FillElement and size: w:200, hch:1": ->
        for value, result of {
            top:
              area:       rect 0, 0, 135, 52
              drawArea:   rect -8, -8, 150, 72
              element:
                logicalArea:            rect -20, -10, 200, 72
                paddedArea:             rect 0, 0, 160, 52
                elementSpaceDrawArea:   rect -8, -8, 150, 72
            }
          do (value, result) =>
            drawTest3 "align: '#{value}'",
              stagingBitmapsCreateShouldBe: 0
              element: ->
                new TextElement
                  size:     w:200, hch:1
                  padding:  h:20, v:10
                  color:    "red"
                  text:     "The quick brown fox jumped over the lazy dog."
                  fontSize: 16
                  align:    value
                  new FillElement() # IMPORTANT FOR THIS TEST - DONT REMOVE
              test: (element) -> layoutTester element, result

      "width change in second layout pass should update alignments": ->
        for align, result of {
            right:
              fragments:
                width: min: [112], max: [118]
                left: [0]
            }
          do (align, result) =>
            drawTest3 "align: '#{align}'",
              stagingBitmapsCreateShouldBe: 0
              element: ->
                new Element
                  size: w:150, hch: 1
                  new TextElement
                    fontSize: 17.5
                    fontFamily: "'HelveticaNeue-Light', sans-serif"
                    color: "red"
                    size: cs: 1, max: ww: 1
                    text: "MMMM! Rajas!"
                    align: align
                    padding: bottom: 9
                    leading: 1.1
                    new RectangleElement color: "#0002"
                    new FillElement

              test: (element) -> layoutTester element.children[0], result

        test "adding a max-size to layout shouldn't effect layout unless max size is hit", ->
          sharedProps =
            margin: 10
            color: "red"
            text: "MMMM! Rajas!"
          el = new Element
            size: w:150, h: 50
            childrenLayout: "column"
            new RectangleElement inFlow: false, color: "#eee"
            c1 = new TextElement merge(sharedProps, size: cs: 1, max: ww: 1),
              new RectangleElement color: "#0002"
              new FillElement
            c2 = new TextElement merge(sharedProps, size: cs: 1),
              new RectangleElement color: "#0002"
              new FillElement
          el.toBitmapBasic()
          .then (bitmap) ->
            log shouldBeSame: bitmap
            assert.lt c1.currentSize.sub(c2.currentSize).abs, point1,
              c1: c1.currentSize
              c2: c2.currentSize
            c1.text = c2.text = "This should word wrap, though!"
            el.toBitmapBasic()
          .then (bitmap) ->
            log shouldBeDifferent: bitmap
            assert.neq c1.currentSize, c2.currentSize

      "layout ww:.5, hh:1": ->
        leftAligned     = [0,   0,    0,    0,    0]
        topAligned      = [0,   20,   40,   60,   80]
        rightAligned    = [50,  50,   50,   50,   50]
        bottomAligned   = [20,  40,   60,   80,   100]
        hCenterAligned  = [25,  25,   25,   25,   25]
        vCenterAligned  = [10,  30,   50,   70,   90]
        for value, result of {
            top:          top:      topAligned,     left:     leftAligned
            left:         top:      topAligned,     left:     leftAligned
            center:       top:      topAligned,     hCenter:  hCenterAligned
            right:        top:      topAligned,     right:    rightAligned
            bottom:       bottom:   bottomAligned,  left:     leftAligned
            topLeft:      top:      topAligned,     left:     leftAligned
            topCenter:    top:      topAligned,     hCenter:  hCenterAligned
            topRight:     top:      topAligned,     right:    rightAligned
            centerLeft:   vCenter:  vCenterAligned, left:     leftAligned
            centerCenter: vCenter:  vCenterAligned, hCenter:  hCenterAligned
            centerRight:  vCenter:  vCenterAligned, right:    rightAligned
            bottomLeft:   bottom:   bottomAligned,  left:     leftAligned
            bottomCenter: bottom:   bottomAligned,  hCenter:  hCenterAligned
            bottomRight:  bottom:   bottomAligned,  right:    rightAligned
            }
          do (value, result) =>
            drawTest3 "align: '#{value}'",
              stagingBitmapsCreateShouldBe: 0
              element: ->
                new TextElement
                  size: w:50, h:100
                  align: value
                  color:"red", text:"The quick brown fox jumped over the lazy dog.", fontSize:16
                  new RectangleElement color: "#0002"
                  new FillElement()
              test: (element) -> layoutFragmentTester element, result

      "layout ww:1, hch:1": ->
        leftAligned     = [0,   0,    0,    0   ]
        rightAligned    = [100, 100,  100,  100 ]
        hCenterAligned  = [50,  50,   50,   50  ]
        topAligned      = [0,   20,   40,   60  ]
        for value, result of {
            top:          top:  topAligned, left:     leftAligned
            centerCenter: top:  topAligned, hCenter:  hCenterAligned
            bottomRight:  top:  topAligned, right:    rightAligned
            }
          do (value, result) =>
            drawTest3 "align: '#{value}'",
              stagingBitmapsCreateShouldBe: 0
              element: ->
                new TextElement
                  size: w:100, hch:1
                  align: value
                  color:"red", text:"The quick brown fox jumped over the lazy dog.", fontSize:16
                  new RectangleElement color: "#0002"
                  new FillElement()
              test: (element) -> layoutFragmentTester element, result

    "one line, cs: 1 should mean alignment has no effect": ->
      leftAligned     = [0,   ]
      topAligned      = [0,   ]
      w = [46]
      h = [12]
      for value, result of {
          top:          top:  topAligned, left: leftAligned, w: w, h: h
          centerCenter: top:  topAligned, left: leftAligned, w: w, h: h
          bottomRight:  top:  topAligned, left: leftAligned, w: w, h: h
          }
        do (value, result) =>
          drawTest3 "align: '#{value}'",
            stagingBitmapsCreateShouldBe: 0
            element: ->
              new TextElement
                size: cs:1
                align: value
                color:"red", text:"Thingy", fontSize:16
                new RectangleElement color: "#0002"
                new FillElement()
            test: (element) -> layoutFragmentTester element, result

    "layoutMode: tight": ->
      ###
      NOTES / TODO

      Okay, I need to refactor text layout. Right now the fragment.area variable isn't really an area.
      The location is used for where to tell Canvas to draw the text. It isn't the upper-left corner
      of the area enclosing the text. This is just "wrong."
      I also think we should just drop using rectangles at all and just store the components. It's
      a little more code, but its a lot less GC pressure.
      So, I need the following:
        logicalLocation - the upper-left corner of the logical area
          logical area is the exact area if using tight0 - otherwise it is the textual area
        logicalSize
        textLocationOffset - the offsets to add to logicalLocation to get the coordinates to pass to Canvas for drawing
        drawAreaOffset - add to logicalLocation to get the drawArea location
        drawAreaSize - size of the draw area
      I'm thinking of making a new object for Fragments. Then I can package most the logic
      for managing those values as X/Y Number-value-members.

      ###
      leftAligned     = [0    ]
      topAligned      = [0    ]
      rightAligned    = [100  ]
      bottomAligned   = [100  ]
      hCenterAligned  = [50   ]
      vCenterAligned  = [50   ]
      for value, result of {
          top:          top:      topAligned,     left:     leftAligned, h: {min:[29],max:[31]}, w: min:[43], max:[44]
          left:         top:      topAligned,     left:     leftAligned
          center:       top:      topAligned,     hCenter:  hCenterAligned
          right:        top:      topAligned,     right:    rightAligned
          bottom:       bottom:   bottomAligned,  left:     leftAligned
          topLeft:      top:      topAligned,     left:     leftAligned
          topCenter:    top:      topAligned,     hCenter:  hCenterAligned
          topRight:     top:      topAligned,     right:    rightAligned
          centerLeft:   vCenter:  vCenterAligned, left:     leftAligned
          centerCenter: vCenter:  vCenterAligned, hCenter:  hCenterAligned
          centerRight:  vCenter:  vCenterAligned, right:    rightAligned
          bottomLeft:   bottom:   bottomAligned,  left:     leftAligned
          bottomCenter: bottom:   bottomAligned,  hCenter:  hCenterAligned
          bottomRight:  bottom:   bottomAligned,  right:    rightAligned
          }
        do (value, result) =>
          drawTest3 "align: '#{value}'",
            stagingBitmapsCreateShouldBe: 0
            element: ->
              new TextElement
                layoutMode: "tight0"
                size: pts: 100
                align: value
                color:"red", text:"(Q)", fontSize:32
                new RectangleElement color: "#0002"
                new FillElement()
            test: (element) -> layoutFragmentTester element, result
