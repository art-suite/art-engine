define [
  'art-foundation'
  'art-atomic'
  'art-engine'
  './state_epoch_test_helper'
], (Foundation, Atomic, {Core:{Element}}, StateEpochTestHelper) ->

  {inspect, log, isArray, compact, flatten} = Foundation
  {point, matrix} = Atomic
  {stateEpochTest} = StateEpochTestHelper

  reducedRange = (data, factor = 32) ->
    parseInt (a + factor/2) / factor for a in data


  suite "Art.Engine.Core.Element", ->
    suite "children", ->
      stateEpochTest "new element", ->
        element = new Element
        assert.eq element.pendingChildren, []
        ->
          assert.eq element.children, []
          assert.ok !element.parent?

      stateEpochTest "addChild", ->
        parent = new Element
        child = new Element
        result = parent.addChild child
        ->
          assert.equal result, child
          assert.equal child.parent, parent
          assert.eq parent.children, [child]

      stateEpochTest "delarative Element structure creation", ->
        a = new Element null,
          new Element location: 10, size: 50,
            new Element size: 50
          new Element location: 40, size: 20

        ->
          assert.eq a.children.length, 2
          assert.eq a.children[0].children.length, 1
          assert.eq a.children[1].children.length, 0

      stateEpochTest "addChild to a new parent", ->
        parent = new Element name:"parent"
        parent2 = new Element name:"parent2"
        child = new Element name:"child"
        parent.addChild child

        ->
          assert.eq parent.children, [child]
          assert.eq child.parent, parent
          parent2.addChild child

          ->
            assert.eq parent.children, []
            assert.eq child.parent, parent2
            assert.eq parent2.children, [child]

      stateEpochTest "change child's parent twice in one epoch", ->
        parent = new Element
        parent2 = new Element
        child = new Element
        parent.addChild child
        parent2.addChild child

        ->
          assert.eq parent.children, []
          assert.eq child.parent, parent2
          assert.eq parent2.children, [child]

      stateEpochTest "removeChild", ->
        parent = new Element name:"parent"
        child = new Element name:"child"
        parent.addChild child

        ->
          result = parent.removeChild child
          assert.eq result, child
          ->
            assert.eq child.parent, null
            assert.eq parent.children, []

      stateEpochTest "removeFromParent", ->
        parent = new Element
        child = new Element
        parent.addChild child
        result = child.removeFromParent()

        ->
          assert.eq result, parent
          assert.ok !child.parent?
          assert.eq parent.children, []

      stateEpochTest "bulk-set Children", ->
        parent = new Element
        child1 = new Element
        child2 = new Element
        child3 = new Element
        parent.children = list = [child1, child2, child3]

        ->
          assert.eq parent.children, list
          assert.equal child1.parent, parent
          assert.equal child2.parent, parent
          assert.equal child3.parent, parent

      stateEpochTest "bulk-set Children with nulls", ->
        parent = new Element
        child1 = new Element
        child2 = new Element
        child3 = new Element
        parent.children = list = [child1, child2, null, child3]

        ->
          assert.eq parent.children, compact list
          assert.equal child1.parent, parent
          assert.equal child2.parent, parent
          assert.equal child3.parent, parent

      stateEpochTest "bulk-set Children with nested lists", ->
        parent = new Element
        child1 = new Element
        child2 = new Element
        child3 = new Element
        parent.children = list = [child1, [child2, child3]]

        ->
          assert.eq parent.children, flatten list
          assert.equal child1.parent, parent
          assert.equal child2.parent, parent
          assert.equal child3.parent, parent


      stateEpochTest "bulk-set re-order", ->
        parent = new Element name:"parent"
        child1 = new Element name:"child1"
        child2 = new Element name:"child2"
        child3 = new Element name:"child3"
        parent.children = list1 = [child1, child2, child3]
        list2 = null
        ->
          parent.children = list2 = [child1, child3, child2]

          ->
            assert.eq parent.children, list2

      #   assert.neq parent.children, list1
      #   assert.eq parent.children, list2

      stateEpochTest "set child parent adds child to parent", ->
        parent = new Element
        child = new Element
        child.parent = parent

        ->
          assert.equal child.parent, parent
          assert.eq parent.children, [child]

      stateEpochTest "set child.parent = null removes from parent", ->
        parent = new Element
        child = new Element
        parent.addChild child
        child.parent = null

        ->
          assert.equal child.parent, null
          assert.eq parent.children, []

      stateEpochTest "moveBelow", ->
        parent = new Element
        children = [
          parent.addChild new Element
          parent.addChild new Element
          parent.addChild new Element
        ]
        ->
          assert.eq parent.children, children
          children[2].moveBelow children[1]

          ->
            assert.eq parent.children.length, 3
            assert.eq parent.children[0], children[0]
            assert.eq parent.children[1], children[2]
            assert.eq parent.children[2], children[1]

      stateEpochTest "prev and nextSibling getters", ->
        parent = new Element
        c1 = parent.addChild new Element
        c2 = parent.addChild new Element
        c3 = parent.addChild new Element

        cX = new Element

        ->
          assert.eq c1.nextSibling, [parent, c2]
          assert.eq c2.nextSibling, [parent, c3]
          assert.eq c3.nextSibling, [parent, null]
          assert.eq cX.nextSibling, [null, null]

          assert.eq c1.prevSibling, [parent, null]
          assert.eq c2.prevSibling, [parent, c1]
          assert.eq c3.prevSibling, [parent, c2]
          assert.eq cX.prevSibling, [null, null]

      test "nextSibling setters", ->
        parent = new Element
        c1 = parent.addChild new Element
        c2 = parent.addChild new Element
        c3 = parent.addChild new Element

        cX = new Element

        cX.nextSibling = c1;   assert.eq parent.pendingChildren, [cX, c1, c2, c3]
        cX.nextSibling = c2;   assert.eq parent.pendingChildren, [c1, cX, c2, c3]
        cX.nextSibling = c3;   assert.eq parent.pendingChildren, [c1, c2, cX, c3]
        cX.nextSibling = null; assert.eq parent.pendingChildren, [c1, c2, c3, cX]

        cX.nextSibling = [parent, c1  ]; assert.eq parent.pendingChildren, [cX, c1, c2, c3]
        cX.nextSibling = [parent, c2  ]; assert.eq parent.pendingChildren, [c1, cX, c2, c3]
        cX.nextSibling = [parent, c3  ]; assert.eq parent.pendingChildren, [c1, c2, cX, c3]
        cX.nextSibling = [parent, null]; assert.eq parent.pendingChildren, [c1, c2, c3, cX]

        cX.nextSibling = [null, null]; assert.eq parent.pendingChildren, [c1, c2, c3]; assert.eq cX.pendingParent, null

      test "prevSibling setters", ->
        parent = new Element
        c1 = parent.addChild new Element
        c2 = parent.addChild new Element
        c3 = parent.addChild new Element

        cX = new Element

        cX.prevSibling = c1;   assert.eq parent.pendingChildren, [c1, cX, c2, c3]
        cX.prevSibling = c2;   assert.eq parent.pendingChildren, [c1, c2, cX, c3]
        cX.prevSibling = c3;   assert.eq parent.pendingChildren, [c1, c2, c3, cX]
        cX.prevSibling = null; assert.eq parent.pendingChildren, [cX, c1, c2, c3]

        cX.prevSibling = [parent, c1  ]; assert.eq parent.pendingChildren, [c1, cX, c2, c3]
        cX.prevSibling = [parent, c2  ]; assert.eq parent.pendingChildren, [c1, c2, cX, c3]
        cX.prevSibling = [parent, c3  ]; assert.eq parent.pendingChildren, [c1, c2, c3, cX]
        cX.prevSibling = [parent, null]; assert.eq parent.pendingChildren, [cX, c1, c2, c3]

        cX.prevSibling = [null, null]; assert.eq parent.pendingChildren, [c1, c2, c3]; assert.eq cX.pendingParent, null

      stateEpochTest "addChildBelow", ->
        parent = new Element
        children = [
          parent.addChild new Element name:"child0"
          newChild = new Element name:"newChild"
          refChild = parent.addChild new Element name:"child1"
          parent.addChild new Element name:"child2"
        ]

        ->
          parent.addChildBelow newChild, refChild

          -> assert.eq parent.children, children

      stateEpochTest "addChildAbove", ->
        parent = new Element
        children = [
          parent.addChild new Element name:"child0"
          refChild = parent.addChild new Element name:"child1"
          newChild = new Element name:"newChild"
          parent.addChild new Element name:"child2"
        ]

        ->
          parent.addChildAbove newChild, refChild

          -> assert.eq parent.children, children

      stateEpochTest "moveBelowMask", ->
        parent = new Element
        children = [
          parent.addChild new Element name:"child0"
          parent.addChild new Element name:"child1"
          parent.addChild new Element name:"child2"
        ]
        assert.eq parent.pendingChildren, children
        children[0].isMask = true

        ->
          children[2].moveBelowMask()

          ->
            assert.eq parent.children.length, 3

            assert.eq parent.children[0], children[2]
            assert.eq parent.children[1], children[0]
            assert.eq parent.children[2], children[1]
