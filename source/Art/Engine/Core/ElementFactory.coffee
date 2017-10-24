'use strict';
Foundation = require 'art-foundation'
{BaseObject, timeout, inspect} = Foundation

module.exports = class ElementFactory extends BaseObject
  @singletonClass()

  @newElement: (elementClassName, props, children) => @singleton.newElement elementClassName, props, children

  constructor: ->
    super
    @_elementClasses = {}

  @classGetter
    elementClasses: -> @singleton._elementClasses

  register: (klass) ->
    name = klass.name
    if @_elementClasses[name]
      timeout 100, => # timeout so namespacePath is updated
        console.warn "ElementFactory: element with class-name #{name} already exists. ClassPaths: Existing: #{@_elementClasses[name].namespacePath}, Adding: #{klass.namespacePath}"
    else
      @_elementClasses[name] = klass

  classForElement: (elementClassName) -> @_elementClasses[elementClassName]

  newElement: (elementClassName, props, children) ->
    klass = @_elementClasses[elementClassName]
    throw new Error "ElementFactor: class not found for #{inspect elementClassName} (props: #{inspect props})" unless klass
    new @_elementClasses[elementClassName] props, children
