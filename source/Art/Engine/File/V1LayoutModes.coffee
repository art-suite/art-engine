
module.exports = layoutModes =
  leftAddWidthFixed:      0
  rightAddWidthFixed:     1 #Right-Add means take the parent's right edge and add this many units to find this object's right edge
  centeredWidthFixed:     2

  #Children Defined Widths - means take the width of this object's children and add the appropriate RelVal
  leftAddWidthChildren:   3
  rightAddWidthChildren:  4
  centeredWidthChildren:  5

  #Parent Defined Widths:
  bothAdd:                6 #Both-Add means take the parent's Left and Right edges and add so many units to each to get this object's Left and Right edges respectively
  bothMul:                7 #Left and Right are both expressed as a % of the parent's width - relayout internally
  bothStretch:            8

for k, v of layoutModes
  layoutModes[v] = k
