{log, compactFlatten, formattedInspect , find, each} = require 'art-standard-lib'
{addDirtyDrawArea, validateDrawAreas} = Neptune.Art.Engine.Drawing.ElementDrawLib
{rect} = Neptune.Art.Atomic

validateDrawAreas = (newDrawAreas, oldDrawAreas, addedDrawArea) ->
  areasToTest = compactFlatten [oldDrawAreas, addedDrawArea]
  each areasToTest, (area) ->
    found = find newDrawAreas, (newDrawArea) ->
      # log test: {newDrawArea, area}
      newDrawArea.contains area
    unless found
      throw new Error "expected one of #{formattedInspect newDrawAreas} to contain #{area}"

addAndValidateAll = (areasToAdd) ->
  drawAreas = null
  each areasToAdd, (area) ->
    newDrawAreas = addDirtyDrawArea drawAreas, area
    validateDrawAreas newDrawAreas, drawAreas, area
    drawAreas = newDrawAreas
  drawAreas

module.exports = suite:
  basic: ->
    test "add first", ->
      addAndValidateAll [rect 40]

    test "add second identical", ->
      assert.eq [rect 40], addAndValidateAll [rect(40), rect 40]

    test "add second non-overlapping", ->
      a = addAndValidateAll [
        rect 40
        rect 0, 50, 40, 40
      ]
      assert.eq 2, a.length

    test "add second overlapping", ->
      a = addAndValidateAll [
        rect 40
        rect 0, 30, 40, 40
      ]
      assert.eq a.length, 1

    test "second overlap triggers first overlap", ->
      assert.eq(
        addAndValidateAll([
          rect 20
          rect 20,  1,  1,  38
          rect 1,   20, 37, 1
        ])
        [rect 0, 0, 38, 39]
      )

    test "add second barely overlapping", ->
      a = addAndValidateAll [
        rect 40
        rect 39, 39, 40, 40
      ]
      assert.eq a.length, 1

    test "add second barely not overlapping", ->
      a = addAndValidateAll [
        rect 40
        rect 40, 40, 40, 40
      ]
      assert.eq a.length, 2

  regressions: ->
    test "regression 1", ->
      addAndValidateAll [
        rect(0, 274, 779, 32)
        rect(0, 306, 779, 32)
        rect(0, 274, 779, 32)
      ]
