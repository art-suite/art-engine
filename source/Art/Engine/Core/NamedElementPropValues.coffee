{object} = require 'art-standard-lib'
{PointLayout} = require "../Layout"
{pointLayout} = PointLayout

module.exports =
  # NamedElementPropValues
  namedSizeLayoutsRaw: namedSizeLayoutsRaw =
    parentSize:                               ps:1
    childrenSize:                             cs:1
    parentHeightSquare:                       hh:1, wh:1
    parentWidthSquare:                        hw:1, ww:1
    parentFitSquare:                          hh:1, wh:1, max: hw:1, ww: 1
    childrenSizeMaxParentWidth:               cs:1, max: ww: 1
    childrenSizeMaxParentHeight:              cs:1, max: hh: 1

    parentHeightChildrenWidth:                hh:1, wcw:1
    childrenWidthParentHeight:                hh:1, wcw:1

    parentWidthChildrenHeight:                ww:1, hch:1
    childrenHeightParentWidth:                ww:1, hch:1
    parentWidthChildrenHeightMaxParentHeight: ww:1, hch:1, max: hh: 1
    childrenHeightParentWidthMaxParentHeight: ww:1, hch:1, max: hh: 1

    parentHeightChildrenWidthMaxParentWidth:  wcw:1, hh:1, max: ww:1

  namedSizeLayouts: object namedSizeLayoutsRaw, (v) -> pointLayout v
