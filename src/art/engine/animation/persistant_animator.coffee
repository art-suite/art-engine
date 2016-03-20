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

----------------------------------
INITIAL SUPPORT

ELEMENT SUPPORT (March 2016)

  New property: animators
    Legal values:

      # basic: just name the property to animate to get the default animator
      animators: "location"

      # init a standard animator with custom options:
      animators:
        location:
          d/duration: .25
          f/function: "easeInQuad"

      # start a fully custom animator
      animators:
        location: new CustomAnimator

  Animatable properties:

    Ideally: every concrete property

    This includes both "location" and "currentLocation".

    For currentLocation/currentSize, the animator preprocessor is applied on the output
    of the location and size layouts before _currentLocation or _currentSize are created.

----------------------------------
FUTURE FEATURES

ONE ANIMATOR OVER MULTIPLE PROPS

  I can imagine situations where you might want one animator to be responsible for multiple props.

  Maybe a cartoon-physics animator might want to animate some combination of size, location and scale.

  Clearly, we'd only add this when we really needed it.

  In the cartoon-physics example, it's a 'canned effect'. You'd probably prefer to have the CartoonPhsyics
  animator decide what props it needs to animate. So, perhaps you can specify animators w/o specifying props.
  Instead, the animator itself lists the props it will animate:

  animators: new CartoonPhysicsAnimator

  You can always make an array with multiple different animators specified using any legal method.
  animators: [
    new CartoonPhysicsAnimator
    "color"
  ]

  Once we have that, we may have more than one animator for the same property. Gut says it works like "merge".
  The last specified animator gets sole responsibilty for animating that prop.

  How does an animator for multiple props work? Normally each prop is handled individually. In the case
  of layout-props, they don't even get handled at the same time as the other props. They get handled during
  layout. So, I think the multi-prop animator needs to be able to process each prop in isolation.

ANIMATING WHEN SWITCHING PARENTS

  Use-case:

    Show a thumbnail in a list.
    Tap it to zoom in.
    Animated from the thumbnail to the full-sized view.

  How it might work:

    The Thumbnail gets a unique key.

    The ZoomIn can set its createdFrom props to be taken from another element via its key.

  Need:

    Special-case animated virtual property:
      elementToAbsMatrix

    For nicer animations when scaling and angles are involed, we may add these animatable virtual props:
      absoluteCurrentLocation (new)
      absoluteCurrentScale (new)
      absoluteCurrentAngle (new)

    Enhanced props:
      added/createdFrom:
        element: elementKey or element
        props: props-name list

    Could allow initializing *From from several source elements or
    specific props. All results are passed into "merge":

    added/createdFrom: [
      {element: elementKey1, props: propsString1}
      {element: elementKey2, props: propsString2}
      color: "red"
      ]

  How it might look in user-code:

    Thumbnail = createComponentFactory
      render: ->
        {itemId} = @props
        Element
          key: "thumbnail:#{itemId}"
          ...

    ZoomIn = createComponentFactory
      render: ->
        {itemId} = @props
        Element
          createdFrom:
            element: "thumbnail:#{itemId}"
            props: "elementToAbsMatrix"

          animators: "elementToAbsMatrix"

ADDED / REMOVED ANIMATIONS (March 2016)
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
        removedTo:    location: -10

SELECTING ELEMENTS BY KEY

  When specifying createdFrom: element: elementKey, how do we match the elementKey with
  a concrete element?

  There are both performance concerns and usability concerns:

    performance:
      - there may be a lot of elements with keys; how do we find a match quickly?
      - a pre-computed & maintained hash is probably the answer... but that may be a lot of work.
    useability:
      - duplicate keys
      - do we need scoping to reduce key-collisions / avoid "globals" / isolate components?

  It seems to me that some amount of scoping would both reduce the number of keys that need
  to be inspected for a lookup / or reduce the work necessary to maintain a precomputed hash.

ELEMENT "KEY" SCOPING BY COMPONENT

  We could scope by "Component". ArtReact already has this information, so the user
  doesn't have to do any additional work.

  - An Element can be flagged as a Component.
  - This would automatically be done by React Components.
  - All Elements in its sub-branch are part of that component,
  - EXCEPT for any Elements which are themselves Components - i.e. SubComponents.
  - Any Element can ask for its parent Component.
  - Every Component maintains a hash of Element keys to Elements for every Element in that Component.
  - Automatic warnings for duplicate "key" values for children who have keys within a component.
    When this happens, the second, duplicate key is renamed to be unique via an appended string.

  Global-scoping vs relative scoping

  I'd rather avoid anything global, but to handle the "animated thumbnail-zoom-in" use-case, we
  will need a way for one element to reference another in a different component. I think the
  rought idea would be some way to express:

  - "within my parent component with key XYZ"
  - "within its subcomponent with key ABC"
  - "select element with key LMO"

  Basically, we can navigate the 'component-defined-key-namespace-tree' by first scanning UP,
  then scanning down, and then select an element within the resulting selected component.

  This avoids ever going to a global scope. There could be other components that use the same
  keys and it wouldn't interfere with this lookup.

  How it might look:

    element:
      withinParentComponent: "XYZ"
      findChildComponent: "ABC"
      findElement: "LMO"

  We could also decide to have a "selector" shorthand:

    element: "^XYZ/** /ABC/LMO"

    HRM - coffeescript doesn't allow * followed by / in a comment block. Makes sense, but I had
      to add a space after '**' above. Ignore the space :).

    split on '/'
    '^' means search up for the first component that matches the rest of the string
    '**' means match any path of sub-components

  When "pathing" sub-components and sub-elements are both found in the same key-lookup-hash.
  The only difference is the key-loopup-hash that is used is found in the first component-element
  at of above the current element. So, if you path to a sub-component, the next key will select
  from within that component, but if you path to just an element, the next key could jump you to
  any other element within the same parent component.

  Possibly we just make this illegal. If you attempt to path "into" an element which is not a component,
  it's an error - logged in debug mode and returning a null result.

  How can we make '**' fast? Each component-element can have a list of all sub-components so we don't
  have to enumerate all elements. That still requires tree traversal. We could maintain pre-computed
  hashs, but anytime an anything changes in the tree that could be quite a lot of updates. Every parent
  needs to be updated since ** could be triggered from any parent to any child.

----------------------------------
REACT IMPLICATIONS

"keys" need to become component-wide, not just Parent-scoped.

Does this mean we still need the following limitation for Component roots?
  a) must be a single element
  b) can't change its Element-type.

NOTE: Span elements will make this less onerous. Just wrap the root in a Span and you can
  do whatever you want within that span as-if you were just returning an array of elements.

###

Foundation = require 'art-foundation'
Events = require 'art-events'
EasingFunctions = require './easing_functions'

{
  log, BaseObject
  isFunction, isString
} = Foundation
{EventedObject} = Events

###
Animator is created once, when the Element is created (or the animators prop is set).
It persists as long as the animator property is set and points to it.
If can be "active" or not. If active, that element will get an epoch update each
frame, and the animator will get a chance to animate the property each frame.

Options:
  on:
    done: ->   # fires when the animation completes
    update: -> # fires every time the target object's animated values updated
    start: ->  # fires when the animation starts
    abort: ->  # fires when the animation aborts

###

module.exports = class PersistantAnimator extends BaseObject
  @include EventedObject

  @interpolate: (startValue, toValue, pos) ->
    if isFunction startValue.interpolate
      startValue.interpolate toValue, pos
    else
      startValue + (toValue - startValue) * pos

  @getter "active options prop"
  @getter
    # state is provided for custom "animate" functions use.
    # animate can store anything in state it chooses.
    state: -> @_state ||= {}

  ###
  IN:
    options:
      animate: (startValue, currentValue, toValue, secondsSinceStart, animator) -> nextValue
        IN:
          startValue: the value when the aniation started
          currentValue: the element's current value
          toValue: the requested target value for the animation
          secondsSinceStart: seconds since the animation started
          animator: this PersistantAnimator object

        OUT: the next value in the animation

        SHOULD:
          Call animator.stop() when the animation is done.
          The animation can run forever and never call stop if desired.
          TODO: how do we release a forever animation?

        STATE:
          Use animator.state object to store any persistant state the animation function needs.
          animator.state is reserved for exclusive use by the animate function.
  ###
  constructor: (prop, options)->
    @_prop = prop
    @_setterName = BaseObject._propSetterName prop
    @_options = options
    @_active = false
    @_startSecond = null
    @_currentSecond = null
    @_startValue = null
    @_animate = options.animate
    @on options.on if options?.on

  @getter
    deltaSecond: -> @_currentSecond - @_startSecond

  stop: -> @_active = false

  animate: (startValue, currentValue, toValue, secondsSinceStart) ->
    if @_animate
      @_animate startValue, currentValue, toValue, secondsSinceStart, @
    else
      @_active = false
      toValue

  animateAbsoluteTime: (element, currentValue, toValue, @_currentSecond) ->
    if !@_active
      @_startSecond = @_currentSecond
      @_startValue = currentValue
      @queueEvent "start"
      @_active = true

    deltaSecond = @getDeltaSecond()

    newValue = @animate @_startValue, currentValue, toValue, deltaSecond

    if @_active
      @queueEvent "update" if deltaSecond > 0
      element.onNextEpoch => element[@_setterName] toValue
    else
      @queueEvent "done"

    newValue
