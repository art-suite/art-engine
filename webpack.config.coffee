module.exports = (require "art-foundation/configure_webpack")
  entries: "index test"
  dirname: __dirname
  package:
    dependencies:
      "art-foundation": "git://github.com/imikimi/art-foundation.git"
      "art-canvas":     "git://github.com/imikimi/art-canvas.git"
      "art-events":     "git://github.com/imikimi/art-events.git"
      "art-xbd":        "git://github.com/imikimi/art-xbd.git"
      "art-text":       "git://github.com/imikimi/art-text.git"
      "keyboardevent-key-polyfill": "^1.0.2",
      "javascript-detect-element-resize": "^0.5.3"
