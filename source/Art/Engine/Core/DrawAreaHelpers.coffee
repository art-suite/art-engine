{defineModule, compactFlatten, log, each, find, arrayWithout} = require 'art-standard-lib'

defineModule module, class DrawAreaHelpers
  @validateDrawAreas: (newDrawAreas, oldDrawAreas, addedDrawArea) ->
    areasToTest = compactFlatten [oldDrawAreas, addedDrawArea]
    each areasToTest, (area) ->
      unless (find newDrawAreas, (newDrawArea) -> newDrawArea.contains area)
        throw new Error "expected one of #{formattedInspect newDrawAreas} to contain #{area}"

  @findFirstOverlappingAreaIndex: (areas, testArea) ->
    for area, i in areas when area.overlaps testArea
      return i

  @addDirtyDrawArea: (dirtyDrawAreas, dirtyArea) =>

    if dirtyArea.area > 0

      dirtyArea = dirtyArea.roundOut()

      if dirtyDrawAreas

        while (overlapIndex = @findFirstOverlappingAreaIndex dirtyDrawAreas, dirtyArea)?
          dirtyArea = dirtyArea.union dirtyDrawAreas[overlapIndex]
          dirtyDrawAreas = arrayWithout dirtyDrawAreas, overlapIndex

        dirtyDrawAreas.push dirtyArea

      else
        dirtyDrawAreas = [dirtyArea]

      @validateDrawAreas dirtyDrawAreas, dirtyArea

    dirtyDrawAreas
