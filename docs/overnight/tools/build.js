// Builds a static page that renders the real dispatch board template + controller
// with stubbed Zammad runtime and fixture jobs, for layout screenshots.
const fs = require('fs'), path = require('path')
const coffee = require('coffee-script'), eco = require('eco')
const R = process.argv[2], OUT = process.argv[3]
const js = (p) => fs.readFileSync(path.join(R, p), 'utf8')
const cs = (p) => coffee.compile(js(p))
let tpl = ''
for (const name of ['board']) {
  tpl += `window.JST['dom_servis_dispatch/${name}'] = ${eco.precompile(js(`app/assets/javascripts/app/views/dom_servis_dispatch/${name}.jst.eco`))};\n`
}
const css = ['app/assets/stylesheets/bootstrap.css', 'app/assets/stylesheets/font.css', 'app/assets/stylesheets/svg-dimensions.css'].map(js).join('\n')
  + fs.readFileSync(path.join(__dirname, 'zammad.css'), 'utf8')
  + js('app/assets/stylesheets/addons/dom_servis_dispatch.css')
const page = `<!doctype html><html lang="ru"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no, viewport-fit=cover">
<style>${css}</style></head>
<body class="dom-servis-dispatch-mobile-shell"><div id="app" class="horizontal"><div class="navigation vertical"></div>
<div class="main flex vertical" id="content"><div class="content horizontal flex active dom-servis-dispatch-board"></div></div></div>
<script>${js('app/assets/javascripts/app/lib/core/jquery-3.6.0.js')}</script>
<script>${js('app/assets/javascripts/app/lib/core/underscore-1.8.3.js')}</script>
<script src="stubs.js"></script>
<script>window.JST={};${tpl}</script>
<script>${cs('app/assets/javascripts/app/lib/app_post/dom_servis_dispatch_calendar.coffee')}</script>
<script>${cs('app/assets/javascripts/app/controllers/dom_servis/dispatch_board.coffee')}</script>
<script src="boot.js"></script></body></html>`
fs.writeFileSync(OUT, page)
