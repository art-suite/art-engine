# Art.Engine Events

## Basic Pointer Events

* pointerCancel
* pointerMove (logically the same as pointerDrag)
* pointerUp
* pointerDown
* mouseMove
* mouseIn
* mouseOut
* focus
* blur

## Derived Pointer Events
These events are generated under certain combinations of the basic pointer events.

* pointerUpInside
* pointerUpOutside
* pointerClick
* pointerIn
* pointerOut

## Layout
* childrenFit / childrenDontFit: triggered by row or column childrenLayout when the children do not fit along the main axis

## Animators
* abort
* start
* done
* update