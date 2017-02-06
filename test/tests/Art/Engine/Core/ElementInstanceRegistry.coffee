Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'

{inspect, nextTick, eq, log} = Foundation
{point, matrix, Matrix} = Atomic
{StateEpoch, Element, CanvasElement} = Engine.Core
{stateEpoch} = StateEpoch

HtmlCanvas = Foundation.Browser.DomElementFactories.Canvas

suite "Art.Engine.Core.ElementBase._elementInstanceRegistry", ->

  test 'setting remoteId sets instanceId', ->
    element = new Element
    element.remoteId = myRemoteId = "123xyz"
    assert.eq element.instanceId, myRemoteId

  test 'new Element with no parent is never in the registry', ->
    element = new Element
    assert.eq false, element.isRegistered
    element.onNextReady ->
      assert.eq false, element.isRegistered

  test 'new Element with no parent and new Child, neither should be in the registry', ->
    element = new Element {}
    element.children = [child = new Element]
    assert.eq false, element.isRegistered
    assert.eq false, child.isRegistered
    element.onNextReady ->
      assert.eq false, element.isRegistered
      assert.eq false, child.isRegistered

  test 'new Element with no parent and new Child, neither should be in the registry no matter the creation order', ->
    child = new Element
    element = new Element {}, child
    assert.eq false, element.isRegistered
    assert.eq false, child.isRegistered
    element.onNextReady ->
      assert.eq false, element.isRegistered
      assert.eq false, child.isRegistered

  test 'CanvasElement is automatically registered', ->
    ce = new CanvasElement canvas: HtmlCanvas()
    ce.onNextReady ->
      assert.eq true, ce.isRegistered


  test 'new Element added to CanvasElement is registered', ->
    ce = new CanvasElement canvas: HtmlCanvas()
    child = new Element
    ce.children = [child]
    assert.eq false, child.isRegistered
    ce.onNextReady ->
      assert.eq true, child.isRegistered

  test 'ElementBase.getElementByInstanceId returns the registered element', ->
    ce = new CanvasElement canvas: HtmlCanvas()
    child = new Element
    ce.children = [child]
    assert.eq false, child.isRegistered
    ce.onNextReady ->
      assert.eq child, Element.getElementByInstanceId child.instanceId

  test 'new Element with new child, added to CanvasElement, both are registered', ->
    ce = new CanvasElement canvas: HtmlCanvas()
    parent = new Element {}, [child = new Element]
    ce.onNextReady ->
      ce.children = [parent]
      assert.eq false, parent.isRegistered
      assert.eq false, child.isRegistered
    .then -> ce.onNextReady ->
      assert.eq true, parent.isRegistered
      assert.eq true, child.isRegistered

  test 'new Element with new child, added to CanvasElement, then removed, both are not registered', ->
    ce = new CanvasElement canvas: HtmlCanvas()
    parent = new Element {}, [child = new Element]
    ce.onNextReady ->
      ce.children = [parent]
      assert.eq false, parent.isRegistered
      assert.eq false, child.isRegistered
    .then -> ce.onNextReady ->
      assert.eq true, parent.isRegistered
      assert.eq true, child.isRegistered
      ce.children = []
    .then -> ce.onNextReady ->
      assert.eq false, parent.isRegistered
      assert.eq false, child.isRegistered

  test 'new Element with new child, added to CanvasElement, then child removed, only child is not registered', ->
    ce = new CanvasElement canvas: HtmlCanvas()
    parent = new Element {}, [child = new Element]
    ce.onNextReady ->
      ce.children = [parent]
      assert.eq false, parent.isRegistered
      assert.eq false, child.isRegistered
    .then -> ce.onNextReady ->
      assert.eq true, parent.isRegistered
      assert.eq true, child.isRegistered
      parent.children = []
    .then -> ce.onNextReady ->
      assert.eq true, parent.isRegistered
      assert.eq false, child.isRegistered

