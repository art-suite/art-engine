Foundation = require 'art-foundation'
{BaseObject, timeout, inspect} = Foundation

module.exports = class ElementFactory extends BaseObject
  @singletonClass()

  @newElement: (elementClassName, props, children) => @singleton.newElement elementClassName, props, children

  constructor: ->
    super
    @_elementClassesByName = {}

  register: (klass) ->
    name = klass.name
    if @_elementClassesByName[name]
      timeout 100, => # timeout so namespacePath is updated
        console.warn "ElementFactory: element with class-name #{name} already exists. ClassPaths: Existing: #{@_elementClassesByName[name].namespacePath}, Adding: #{klass.namespacePath}"
    else
      @_elementClassesByName[name] = klass

  classForElement: (elementClassName) -> @_elementClassesByName[elementClassName]

  newElement: (elementClassName, props, children) ->
    klass = @_elementClassesByName[elementClassName]
    throw new Error "ElementFactor: class not found for #{inspect elementClassName} (props: #{inspect props})" unless klass
    new @_elementClassesByName[elementClassName] props, children
