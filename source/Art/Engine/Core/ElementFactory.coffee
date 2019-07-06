'use strict';
Foundation = require 'art-foundation'
{BaseClass, timeout, inspect} = Foundation

module.exports = class ElementFactory extends BaseClass
  @singletonClass()

  @newElement: (elementClassName, props, children, creator) => @singleton.newElement elementClassName, props, children, creator

  constructor: ->
    super
    @_elementClasses = {}

  @classGetter
    elementClasses:     => @singleton._elementClasses
    elementClassNames:  => Object.keys @elementClasses

  register: (klass) ->
    name = klass.name
    if @_elementClasses[name]
      timeout 100, => # timeout so namespacePath is updated
        console.warn "ElementFactory: element with class-name #{name} already exists. ClassPaths: Existing: #{@_elementClasses[name].namespacePath}, Adding: #{klass.namespacePath}"
    else
      @_elementClasses[name] = klass

  classForElement: (elementClassName) -> @_elementClasses[elementClassName]

  newElement: (elementClassName, props, children, creator) ->
    klass = @_elementClasses[elementClassName]
    throw new Error "ElementFactor: class not found for #{inspect elementClassName} (props: #{inspect props})" unless klass
    element = new @_elementClasses[elementClassName] props, children
    element.creator = creator
    element
