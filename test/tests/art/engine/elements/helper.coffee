define [

  'art-foundation'
  'art-atomic'
  'art-canvas'
  'art-engine'
], (Foundation, Atomic, Canvas, Engine) ->
  {log, BaseObject} = Foundation

  {point, Matrix} = Atomic
  {StateEpoch, Element} = Engine.Core
  {stateEpoch} = StateEpoch

  class Helper extends BaseObject
    @drawTest: (element, text, options={})->

      stateEpoch.onNextReady ->
        b = new Canvas.Bitmap element.currentSize.add 20
        b.clear "#eee"
        m = element.elementToParentMatrix.mul Matrix.translate 10

        options.beforeDraw?()
        element.draw b, m
        options.afterDraw?()
        log b, text:"#{text}"
        options.done?()

    # options done: -> # function called just before test's "done()"
    @drawTest2: (text, f, options)=>
      test text, (done) =>
        d2 = if options?.done
          ->
            options.done()
            done()
        else
          done
        @drawTest f(), text, done:d2

    @drawTest3: (text, options={})=>
      test text, (done)=>
        element = options.element()
        stagingBitmapsCreated = stagingBitmapsCreatedBefore = null

        @drawTest element, text,
          beforeDraw: -> stagingBitmapsCreatedBefore = Element.stats.stagingBitmapsCreated
          afterDraw: -> stagingBitmapsCreated = Element.stats.stagingBitmapsCreated - stagingBitmapsCreatedBefore
          done: ->
            if (v = options.stagingBitmapsCreateShouldBe)?
              assert.eq stagingBitmapsCreated, v, "stagingBitmapsCreateShouldBe"
            if (v = options.elementSpaceDrawAreaShouldBe)?
              assert.eq element.elementSpaceDrawArea, v, "stagingBitmapsCreateShouldBe"

            options.test? element

            done()

