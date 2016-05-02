Foundation = require 'art-foundation'
Events = require 'art-events'


###
KeyboardEvent Polyfill

We are using the upcoming (as-of-2016) "DOM Keyboard Level 3 Events".
Info:
  https://w3c.github.io/uievents/#interface-KeyboardEvent
  https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent

This polyfill helps the "key" value of KeyboardEvents be populated consistently across browsers.

Current browser support: http://caniuse.com/#search=keyboardevent.key
Alternative polyfill: https://github.com/termi/DOM-Keyboard-Event-Level-3-polyfill
  (not using because it hasn't been touchedin 3 years and is complex)
###
require('keyboardevent-key-polyfill').polyfill()

{log} = Foundation

module.exports = class KeyEvent extends Events.Event

  constructor: (type, @_keyboardEvent) ->
    self._lastKeyboardEvnet = @_keyboardEvent
    super type,
      key       : @_keyboardEvent.key
      altKey    : @_keyboardEvent.altKey
      ctrlKey   : @_keyboardEvent.ctrlKey
      shiftKey  : @_keyboardEvent.shiftKey
      metaKey   : @_keyboardEvent.metaKey
