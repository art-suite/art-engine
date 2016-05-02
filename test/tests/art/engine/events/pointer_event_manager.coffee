Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'

{Matrix, point} = Atomic
{Pointer, PointerEventManager} = Engine.Events

{sortElementsBaseOnRelationshipPriority} = PointerEventManager

suite "Art.Engine.Events.PointerEventManager.sortElementsBaseOnRelationshipPriority beforeChildren & afterChildren", ->
  test "all combinations of 1 beforeChildren and afterChildren", ->
    assert.eq [0], sortElementsBaseOnRelationshipPriority ["afterChildren"]
    assert.eq [0], sortElementsBaseOnRelationshipPriority ["beforeChildren"]

  test "all combinations of 2 beforeChildren and afterChildren", ->
    assert.eq [1, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "afterChildren"]
    assert.eq [1, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "beforeChildren"]
    assert.eq [0, 1], sortElementsBaseOnRelationshipPriority ["beforeChildren", "afterChildren"]
    assert.eq [0, 1], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeChildren"]

  test "all combinations of 3 beforeChildren and afterChildren", ->
    assert.eq [2, 1, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "afterChildren", "afterChildren"]
    assert.eq [2, 1, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "afterChildren", "beforeChildren"]
    assert.eq [1, 2, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "beforeChildren", "afterChildren"]
    assert.eq [1, 2, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "beforeChildren", "beforeChildren"]

    assert.eq [0, 2, 1], sortElementsBaseOnRelationshipPriority ["beforeChildren", "afterChildren", "afterChildren"]
    assert.eq [0, 2, 1], sortElementsBaseOnRelationshipPriority ["beforeChildren", "afterChildren", "beforeChildren"]
    assert.eq [0, 1, 2], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeChildren", "afterChildren"]
    assert.eq [0, 1, 2], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeChildren", "beforeChildren"]

  test "all combinations of 4 beforeChildren and afterChildren", ->
    assert.eq [3, 2, 1, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "afterChildren", "afterChildren", "afterChildren"]
    assert.eq [3, 2, 1, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "afterChildren", "afterChildren", "beforeChildren"]
    assert.eq [2, 3, 1, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "afterChildren", "beforeChildren", "afterChildren"]
    assert.eq [2, 3, 1, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "afterChildren", "beforeChildren", "beforeChildren"]

    assert.eq [1, 3, 2, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "beforeChildren", "afterChildren", "afterChildren"]
    assert.eq [1, 3, 2, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "beforeChildren", "afterChildren", "beforeChildren"]
    assert.eq [1, 2, 3, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "beforeChildren", "beforeChildren", "afterChildren"]
    assert.eq [1, 2, 3, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "beforeChildren", "beforeChildren", "beforeChildren"]

    assert.eq [0, 3, 2, 1], sortElementsBaseOnRelationshipPriority ["beforeChildren", "afterChildren", "afterChildren", "afterChildren"]
    assert.eq [0, 3, 2, 1], sortElementsBaseOnRelationshipPriority ["beforeChildren", "afterChildren", "afterChildren", "beforeChildren"]
    assert.eq [0, 2, 3, 1], sortElementsBaseOnRelationshipPriority ["beforeChildren", "afterChildren", "beforeChildren", "afterChildren"]
    assert.eq [0, 2, 3, 1], sortElementsBaseOnRelationshipPriority ["beforeChildren", "afterChildren", "beforeChildren", "beforeChildren"]

    assert.eq [0, 1, 3, 2], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeChildren", "afterChildren", "afterChildren"]
    assert.eq [0, 1, 3, 2], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeChildren", "afterChildren", "beforeChildren"]
    assert.eq [0, 1, 2, 3], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeChildren", "beforeChildren", "afterChildren"]
    assert.eq [0, 1, 2, 3], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeChildren", "beforeChildren", "beforeChildren"]

suite "Art.Engine.Events.PointerEventManager.sortElementsBaseOnRelationshipPriority beforeDescendents & afterChildren", ->
  ###
  NOTE: without beforeAncestors, beforeDescendents works identically as beforeChildren
  ###
  test "all combinations of 1 beforeDescendents and afterChildren", ->
    assert.eq [0], sortElementsBaseOnRelationshipPriority ["afterChildren"]
    assert.eq [0], sortElementsBaseOnRelationshipPriority ["beforeDescendents"]

  test "all combinations of 2 beforeDescendents and afterChildren", ->
    assert.eq [1, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "afterChildren"]
    assert.eq [1, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "beforeDescendents"]
    assert.eq [0, 1], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "afterChildren"]
    assert.eq [0, 1], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeDescendents"]

  test "all combinations of 3 beforeDescendents and afterChildren", ->
    assert.eq [2, 1, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "afterChildren", "afterChildren"]
    assert.eq [2, 1, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "afterChildren", "beforeDescendents"]
    assert.eq [1, 2, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "beforeDescendents", "afterChildren"]
    assert.eq [1, 2, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "beforeDescendents", "beforeDescendents"]

    assert.eq [0, 2, 1], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "afterChildren", "afterChildren"]
    assert.eq [0, 2, 1], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "afterChildren", "beforeDescendents"]
    assert.eq [0, 1, 2], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeDescendents", "afterChildren"]
    assert.eq [0, 1, 2], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeDescendents", "beforeDescendents"]

  test "all combinations of 4 beforeDescendents and afterChildren", ->
    assert.eq [3, 2, 1, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "afterChildren", "afterChildren", "afterChildren"]
    assert.eq [3, 2, 1, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "afterChildren", "afterChildren", "beforeDescendents"]
    assert.eq [2, 3, 1, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "afterChildren", "beforeDescendents", "afterChildren"]
    assert.eq [2, 3, 1, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "afterChildren", "beforeDescendents", "beforeDescendents"]

    assert.eq [1, 3, 2, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "beforeDescendents", "afterChildren", "afterChildren"]
    assert.eq [1, 3, 2, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "beforeDescendents", "afterChildren", "beforeDescendents"]
    assert.eq [1, 2, 3, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "beforeDescendents", "beforeDescendents", "afterChildren"]
    assert.eq [1, 2, 3, 0], sortElementsBaseOnRelationshipPriority ["afterChildren", "beforeDescendents", "beforeDescendents", "beforeDescendents"]

    assert.eq [0, 3, 2, 1], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "afterChildren", "afterChildren", "afterChildren"]
    assert.eq [0, 3, 2, 1], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "afterChildren", "afterChildren", "beforeDescendents"]
    assert.eq [0, 2, 3, 1], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "afterChildren", "beforeDescendents", "afterChildren"]
    assert.eq [0, 2, 3, 1], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "afterChildren", "beforeDescendents", "beforeDescendents"]

    assert.eq [0, 1, 3, 2], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeDescendents", "afterChildren", "afterChildren"]
    assert.eq [0, 1, 3, 2], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeDescendents", "afterChildren", "beforeDescendents"]
    assert.eq [0, 1, 2, 3], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeDescendents", "beforeDescendents", "afterChildren"]
    assert.eq [0, 1, 2, 3], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeDescendents", "beforeDescendents", "beforeDescendents"]

suite "Art.Engine.Events.PointerEventManager.sortElementsBaseOnRelationshipPriority beforeChildren & beforeAncestors", ->
  test "basic", ->
    assert.eq [0], sortElementsBaseOnRelationshipPriority ["beforeAncestors"]

  test "all combinations of 2 beforeChildren and beforeAncestors", ->
    assert.eq [1, 0], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeAncestors"]
    assert.eq [0, 1], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeChildren"]
    assert.eq [1, 0], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeAncestors"]
    assert.eq [0, 1], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeChildren"]

  test "all combinations of 3 beforeChildren and beforeAncestors", ->
    assert.eq [2, 1, 0], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeAncestors", "beforeAncestors"]
    assert.eq [1, 2, 0], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeAncestors", "beforeChildren"]
    assert.eq [2, 0, 1], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeChildren", "beforeAncestors"]
    assert.eq [0, 1, 2], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeChildren", "beforeChildren"]

    assert.eq [2, 1, 0], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeAncestors", "beforeAncestors"]
    assert.eq [1, 2, 0], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeAncestors", "beforeChildren"]
    assert.eq [2, 0, 1], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeChildren", "beforeAncestors"]
    assert.eq [0, 1, 2], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeChildren", "beforeChildren"]

  test "all combinations of 4 beforeChildren and beforeAncestors", ->
    assert.eq [3, 2, 1, 0], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeAncestors", "beforeAncestors", "beforeAncestors"]
    assert.eq [2, 3, 1, 0], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeAncestors", "beforeAncestors", "beforeChildren"]
    assert.eq [3, 1, 2, 0], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeAncestors", "beforeChildren", "beforeAncestors"]
    assert.eq [1, 2, 3, 0], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeAncestors", "beforeChildren", "beforeChildren"]

    assert.eq [3, 2, 0, 1], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeChildren", "beforeAncestors", "beforeAncestors"]
    assert.eq [2, 3, 0, 1], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeChildren", "beforeAncestors", "beforeChildren"]
    assert.eq [3, 0, 1, 2], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeChildren", "beforeChildren", "beforeAncestors"]
    assert.eq [0, 1, 2, 3], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeChildren", "beforeChildren", "beforeChildren"]

    assert.eq [3, 2, 1, 0], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeAncestors", "beforeAncestors", "beforeAncestors"]
    assert.eq [2, 3, 1, 0], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeAncestors", "beforeAncestors", "beforeChildren"]
    assert.eq [3, 1, 2, 0], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeAncestors", "beforeChildren", "beforeAncestors"]
    assert.eq [1, 2, 3, 0], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeAncestors", "beforeChildren", "beforeChildren"]

    assert.eq [3, 2, 0, 1], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeChildren", "beforeAncestors", "beforeAncestors"]
    assert.eq [2, 3, 0, 1], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeChildren", "beforeAncestors", "beforeChildren"]
    assert.eq [3, 0, 1, 2], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeChildren", "beforeChildren", "beforeAncestors"]
    assert.eq [0, 1, 2, 3], sortElementsBaseOnRelationshipPriority ["beforeChildren", "beforeChildren", "beforeChildren", "beforeChildren"]

suite "Art.Engine.Events.PointerEventManager.sortElementsBaseOnRelationshipPriority beforeDescendents & beforeAncestors", ->
  test "basic", ->
    assert.eq [0], sortElementsBaseOnRelationshipPriority ["beforeDescendents"]

  test "all combinations of 2 beforeDescendents and beforeAncestors", ->
    assert.eq [1, 0], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeAncestors"]
    assert.eq [0, 1], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeDescendents"]
    assert.eq [0, 1], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeAncestors"]
    assert.eq [0, 1], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeDescendents"]

  test "all combinations of 3 beforeDescendents and beforeAncestors", ->
    assert.eq [2, 1, 0], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeAncestors", "beforeAncestors"]
    assert.eq [1, 2, 0], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeAncestors", "beforeDescendents"]
    assert.eq [0, 1, 2], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeDescendents", "beforeAncestors"]
    assert.eq [0, 1, 2], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeDescendents", "beforeDescendents"]

    assert.eq [0, 2, 1], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeAncestors", "beforeAncestors"]
    assert.eq [0, 1, 2], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeAncestors", "beforeDescendents"]
    assert.eq [0, 1, 2], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeDescendents", "beforeAncestors"]
    assert.eq [0, 1, 2], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeDescendents", "beforeDescendents"]

  test "all combinations of 4 beforeDescendents and beforeAncestors", ->
    assert.eq [3, 2, 1, 0], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeAncestors", "beforeAncestors", "beforeAncestors"]
    assert.eq [2, 3, 1, 0], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeAncestors", "beforeAncestors", "beforeDescendents"]
    assert.eq [1, 2, 3, 0], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeAncestors", "beforeDescendents", "beforeAncestors"]
    assert.eq [1, 2, 3, 0], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeAncestors", "beforeDescendents", "beforeDescendents"]

    assert.eq [0, 1, 3, 2], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeDescendents", "beforeAncestors", "beforeAncestors"]
    assert.eq [0, 1, 2, 3], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeDescendents", "beforeAncestors", "beforeDescendents"]
    assert.eq [0, 1, 2, 3], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeDescendents", "beforeDescendents", "beforeAncestors"]
    assert.eq [0, 1, 2, 3], sortElementsBaseOnRelationshipPriority ["beforeAncestors", "beforeDescendents", "beforeDescendents", "beforeDescendents"]

    assert.eq [0, 3, 2, 1], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeAncestors", "beforeAncestors", "beforeAncestors"]
    assert.eq [0, 2, 3, 1], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeAncestors", "beforeAncestors", "beforeDescendents"]
    assert.eq [0, 1, 2, 3], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeAncestors", "beforeDescendents", "beforeAncestors"]
    assert.eq [0, 1, 2, 3], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeAncestors", "beforeDescendents", "beforeDescendents"]

    assert.eq [0, 1, 3, 2], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeDescendents", "beforeAncestors", "beforeAncestors"]
    assert.eq [0, 1, 2, 3], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeDescendents", "beforeAncestors", "beforeDescendents"]
    assert.eq [0, 1, 2, 3], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeDescendents", "beforeDescendents", "beforeAncestors"]
    assert.eq [0, 1, 2, 3], sortElementsBaseOnRelationshipPriority ["beforeDescendents", "beforeDescendents", "beforeDescendents", "beforeDescendents"]
