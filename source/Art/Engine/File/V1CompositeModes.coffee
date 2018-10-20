
module.exports = compositeModes =
  0: "normal"
  1: "add"
  2: "difference"
  3: "multiply"
  4: "targetTopUnion"
  5: "replace"
  6: "targetTopIntersection"  # alphaMask
  7: "targetWithoutSource"    # inverseAlphaMask
  8: "targetWithoutSource"    # erase - use the alpha of the source bitmap to erase potions of the target. 100% source alpha == 100% erase (set dest alpha to 0%)

for k, v of compositeModes
  compositeModes[v] = k