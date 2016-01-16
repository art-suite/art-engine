###
Useful ideas about optimizing animations and garbage collection: http://blog.artillery.com/2012/10/browser-garbage-collection-and-framerate.html

1) Properties are marked animatable.
2) Every animatable propoerty is animated every time it changes.
3) A new instance of the Animator is created to start the animation.
   - initalValue
   - initialTargetValue
   - initialTime
4) The animator is called each frame with updates:
   - possible changes in targetValue
   - lastFrameTime
   - currentValue
   - currentTime
5) The animator calls "@done()" when it can be released.
  It need not ever be released. It could be endless.
6) Objects

ELEMENT SUPPORT

New properties:
  - for each animatable property, there is an "animator" property.
    Since each animatable has a default animator, it is optional.
    Element
      location: 10
      locationAnimator: EasingAnimator2
        d: .25
        f: "easeInQuad"
  - "from" values
    Each animatable property can have an initial property which gets
    set first. Then, next frame, the normal property value gets set,
    triggering the animator.
    There are two kinds of initial values:
      onCreation - if the Element as added to the parent in the parent's constructor
      onAddition - if the Element as added to the parent sometime later
    Syntax idea:
      new Element
        location: 0
        addedFrom:    location: -10
        createdFrom:  location: -20
  - "parent" special from value:
    addedFrom: parent: xyz
    createdFrom: parent: xyz
    The basic idea is the same as other "from" properties, except this means the Element
    gets added to the "from" parent first, then, next frame, gets added to the actual parent.
    Further, to make this work with React, I think we need these alternatives:
      addedFrom: parentKey: "component-scoped-key-string"
      addedFrom: globalParentKey: "actual-parent's AIM-tree-scoped key-string"
  - "globalKey" property - see below

Component-scoping
  An Element can be flagged as a Component.
  All Elements in its sub-branch are part of that component,
  EXCEPT for any Elements which are themselves Components - i.e. SubComponents.
  Any Element can ask for its parent Component.
  Every Component maintains a hash of Element keys to Elements for every Element in that Component.
  Automatic warnings for duplicate "key" values for children who have keys within a component.
    When this happens, the second, duplicate key is renamed to be unique via an appended string.

Global-scoping & "globalKey" property
  Any Element can have a globalKey. The Root Element has a hash of globalKeys to elements which is maintained
  for its entire subtree.
  Automatic warnings for duplicate "globalKey" values.
    When this happens, the second, duplicate key is renamed to be unique via an appended string.

REACT IMPLICATIONS

"keys" need to become component-wide, not just Parent-scoped.
"globalKeys" need to be added.

This locks us into the current rule: The root of a Component
  a) must be a single element
  b) can't change its Element-type.

However, we could consider adding "span" Elements. These essentially act like a list of Elements as-if
they were directly children of their grand-parent. Obviously this would be groundwork for doing other
SPAN-like things such as supporting bold text in the middle of other text. Generally, this means
properties from the grandparent which apply to the SPAN's children can be overridden by the SPAN -
such as font properties.

VALUE TYPES

* number
* point
* matrix
* color

Maybe we should box "number" so we can treat everything else the same?

MATRIX

Matrix is also a little special cased.
We don't want to linearly animate each of the 6 scalers.
We want to:
  - animate Rotate using rotational inertia
    - values are modulo
    - take the shortest route
    - UNLESS somehow
      - specified to take the long way
      - or even +N additional full rotations
  - animate location using linear inertia
  - animate Scale using z-index linear inertia
  - animate skew... using deformation physics?


NOTE:

###

{currentSecond, min, max, Transaction, inspect, inspectLean, log} = require 'art.foundation'
{color, Color, point, Point, rect, Rectangle, matrix, Matrix} = require 'art.atomic'
{Event, EventEpoch, EasingFunctions} = require 'art.events'
EasingFunctions = require './easing_functions'
{eventEpoch} = EventEpoch

module.exports = class Animator2 extends Foundation.BaseObject
  @include EventedObject

  # It's a FactoryFactory because:
  #   The first Factory captures the options and returns a Factory
  #   for creating an instance-object with those options each time
  #   the animated value changes and needs a new Animator2.
  @createAnimator2FactoryFactory: (Animator2Class)->
    (options) =>
      (animatedElement, iValue, iTarget) =>
        new Animator2Class animatedElement, iValue, iTarget, options

  constructor: (animatedElement, initialValue, initialTargetValue, options = {})->
    super
    @animatedElement = animatedElement
    @options = options
    @on options.on if options?.on

    @lastFrameTime =
    @currentFrameTime   = @initialFrameTime = currentSecond()
    @currentTargetValue = @initialTargetValue = initTargetValue
    @lastValue          = @initialValue = initialValue
    @_isDone = false

    @queueEvent "start"

  @getter
    lastFrameTimeDelta: -> @currentFrameTime - @lastFrameTime
    ellapsedTime:       -> @currentFrameTime - @initialFrameTime
    isDone:             -> @_isDone

  # OVERRIDE
  # Needs to do the following:
  #   return the next value
  #   call @done() when the animation should stop.
  #     NOTE: It's OK if it never stops.
  # This version is a non-animation. It just updates the element to its
  # final target-value and ends the animation.
  advance: ->
    @done()
    @currentTargetValue

  # called by the framework each frame until @isDone returns false
  # returns the next value
  nextValue: (currentFrameTime, currentTargetValue)->
    @lastFrameTime = @currentFrameTime
    @currentFrameTime = currentFrameTime
    @currentTargetValue = currentTargetValue
    @lastValue = @advance()

  # advance calls this when the animation is complete
  # the return value from advance will be the final value
  done: ->
    @_isDone = true

    @queueEvent "done"

  # advance should call this at the beginning of its body,
  # if this is the desired behavior.
  resetOnTargetChange: ->
    if @currentTargetValue != @initialTargetValue
      @initialFrameTime   = @lastFrameTime
      @initialValue       = @lastValue
      @initialTargetValue = @currentTargetValue

Animator2.createAnimator2FactoryFactory class EasingAnimator2 extends Animator2

  constructor: (initialValue, initialTargetValue, options = {})->
    super

    @d = options.d || options.duration || .25
    @f = options.f || options.function || "easeInQuad"

    if isString @f
      ef = EasingFunctions[@f]
      throw new "Invalid EasingFunction name: #{inspect @f}" unless ef
      @f = ef

  interpolate: (fromValue, toValue, pos) ->
    if isFunction fromValue.interpolate
      fromValue.interpolate toValue, pos
    else
      fromValue + (toValue - fromValue) * pos

  advance: ->
    @resetOnTargetChange()

    pos = @ellapsedTime / @d
    if pos < 1
      pos = @f pos
    else
      @done()
      pos = 1

    @interpolate @initialValue, @currentTargetValue, pos


