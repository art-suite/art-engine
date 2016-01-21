{Promise} = Foundation = require 'art-foundation'
Engine = require 'art-engine'

document.onreadystatechange = ->
  if document.readyState == "interactive"
    Neptune.Art.Engine.FullScreenApp.init();

module.exports = appReadyPromise = new Promise

class Neptune.Art.Engine.FullScreenApp

  @init: ->
    query = Foundation.Browser.Parse.query()
    console.log """
      Art.Engine.FullScreenApp options:
        ?dev=true
          show DomConsole
        ?perfGraphs=true
          show performance graphs
      """

    if query.dev == "true" || query.perfGraphs == "true"
      # Art.bindGlobally()
      DomConsole = require 'art-foundation/src/art/dev_tools/dom_console'

      DomConsole.enable()
      Engine.Core.CanvasElement.prototype.defaultSize = hh:1, w: (query.w | 0) || 375
      Engine.DevTools.GlobalEpochStats.enable() if query.perfGraphs == "true"

    console.log "Art.Engine.FullScreenApp: app ready"
    appReadyPromise.resolve()
    Promise.resolve()

  @writeDom: (config = {})->

    {
      title
      styleSheets
      scripts
      fontFamilies
      main # baseUrl relative URL for main.js
    } = config

    title ||= "Art App"
    scripts ||= []
    styleSheets ||= []
    fontFamilies ||= []

    styleSheetLinks = for sheetUrl in styleSheets
      "<link rel='stylesheet' href='#{sheetUrl}' />"

    scriptLinks = for scriptUrl in scripts when scriptUrl
      "<script type='text/javascript' src='#{scriptUrl}'></script>"

    ###
    To include an external font:

      Make sure you load your font with @font-face first in one of the included styleSheets.
      Make sure you add the font-family string specified in your font-face definition to the fontFamilies list.

    This is needed to ensure the font loads.
    TODO: should we us an actual font-loader?
    ###
    fontFamilyInits = for fontFamily in fontFamilies
      "<div style='font-family:#{fontFamily};position:absolute;font-size:0;'>T</div>"

    newLine = "\n    "

    html = """
      <html>
        <head>
          <meta charset="utf-8">
          <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
          <meta name="description" content="">

          <meta name="viewport" content="user-scalable=no, width=device-width, initial-scale=1.0" />
          <meta name="apple-mobile-web-app-capable" content="yes" />
          <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
          <meta name="format-detection" content="telephone=no" />

          <title>#{title}</title>
          #{styleSheetLinks.join newLine}
        </head>

        <style>
          body {
            padding: 0px;
            margin: 0px;
            background-color: #eee;
            overflow: hidden;
          }
          canvas {
            width: 100%;
            height: 100%;
          }
          input:focus {
            outline: 0;
          }
        </style>

        <body>
          #{fontFamilyInits.join newLine}
          <canvas id="artCanvas" moz-opaque></canvas>
          #{scriptLinks.join newLine}
        </body>
      </html>
    """
    document.write html

Neptune.Art.Engine.FullScreenApp.writeDom self.artConfig
