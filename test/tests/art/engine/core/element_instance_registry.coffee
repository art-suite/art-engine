define [
  'extlib/chai'
  'lib/art/foundation'
  'lib/art/atomic'
  'lib/art/engine'
  'lib/art/engine_remote'
], (chai, Foundation, Atomic, Engine, EngineRemote) ->
  {assert} = chai
  {inspect, nextTick, eq, log} = Foundation
  {point, matrix, Matrix} = Atomic
  {StateEpoch, Element, CanvasElement} = Engine.Core
  {stateEpoch} = StateEpoch

  suite "Art.Engine.Core.ElementBase._elementInstanceRegistry", ->

    test 'setting remoteId sets instanceId', ->
      element = new Element
      element.remoteId = myRemoteId = "123xyz"
      assert.eq element.instanceId, myRemoteId

    test 'new Element with no parent is never in the registry', (done)->
      element = new Element
      assert.eq false, element.isRegistered
      element.onNextReady ->
        assert.eq false, element.isRegistered
        done()

    test 'new Element with no parent and new Child, neither should be in the registry', (done)->
      element = new Element {}
      element.children = [child = new Element]
      assert.eq false, element.isRegistered
      assert.eq false, child.isRegistered
      element.onNextReady ->
        assert.eq false, element.isRegistered
        assert.eq false, child.isRegistered
        done()

    test 'new Element with no parent and new Child, neither should be in the registry no matter the creation order', (done)->
      child = new Element
      element = new Element {}, child
      assert.eq false, element.isRegistered
      assert.eq false, child.isRegistered
      element.onNextReady ->
        assert.eq false, element.isRegistered
        assert.eq false, child.isRegistered
        done()

    test 'CanvasElement is automatically registered', (done)->
      ce = new CanvasElement
      ce.onNextReady ->
        assert.eq true, ce.isRegistered
        done()


    test 'new Element added to CanvasElement is registered', (done)->
      ce = new CanvasElement
      child = new Element
      ce.children = [child]
      assert.eq false, child.isRegistered
      ce.onNextReady ->
        assert.eq true, child.isRegistered
        done()

    test 'ElementBase.getElementByInstanceId returns the registered element', (done)->
      ce = new CanvasElement
      child = new Element
      ce.children = [child]
      assert.eq false, child.isRegistered
      ce.onNextReady ->
        assert.eq child, Element.getElementByInstanceId child.instanceId
        done()

    test 'new Element with new child, added to CanvasElement, both are registered', (done)->
      ce = new CanvasElement
      parent = new Element {}, [child = new Element]
      ce.onNextReady ->
        ce.children = [parent]
        assert.eq false, parent.isRegistered
        assert.eq false, child.isRegistered
        ce.onNextReady ->
          assert.eq true, parent.isRegistered
          assert.eq true, child.isRegistered
          done()

    test 'new Element with new child, added to CanvasElement, then removed, both are not registered', (done)->
      ce = new CanvasElement
      parent = new Element {}, [child = new Element]
      ce.onNextReady ->
        ce.children = [parent]
        assert.eq false, parent.isRegistered
        assert.eq false, child.isRegistered
        ce.onNextReady ->
          assert.eq true, parent.isRegistered
          assert.eq true, child.isRegistered
          ce.children = []
          ce.onNextReady ->
            assert.eq false, parent.isRegistered
            assert.eq false, child.isRegistered
            done()

    test 'new Element with new child, added to CanvasElement, then child removed, only child is not registered', (done)->
      ce = new CanvasElement
      parent = new Element {}, [child = new Element]
      ce.onNextReady ->
        ce.children = [parent]
        assert.eq false, parent.isRegistered
        assert.eq false, child.isRegistered
        ce.onNextReady ->
          assert.eq true, parent.isRegistered
          assert.eq true, child.isRegistered
          parent.children = []
          ce.onNextReady ->
            assert.eq true, parent.isRegistered
            assert.eq false, child.isRegistered
            done()
