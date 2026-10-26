// Generates the SmartFlow logo files. Usage: node build-logo.js OUTPUT_DIR
const fs = require('fs')
const path = require('path')

const OUT = process.argv[2]
const SVG_DIR = path.join(OUT, 'svg')
fs.mkdirSync(SVG_DIR, { recursive: true })

const C = { navy: '#0B1F3A', blue: '#1D4ED8', sky: '#9EC0EA', gold: '#F5B83D', white: '#FFFFFF', slate: '#52617A' }

// Rounded rectangle as a path so the eye can have real holes (works on any background).
const rr = (x, y, w, h, r) => `M${x + r} ${y}H${x + w - r}A${r} ${r} 0 0 1 ${x + w} ${y + r}V${y + h - r}A${r} ${r} 0 0 1 ${x + w - r} ${y + h}H${x + r}A${r} ${r} 0 0 1 ${x} ${y + h - r}V${y + r}A${r} ${r} 0 0 1 ${x + r} ${y}Z`

const S_PATH = 'M356 148C302 98 168 100 168 186C168 262 344 248 344 326C344 412 210 414 156 364'
const EX = 356, EY = 148

// The mark: an S drawn as one route. It starts at the gold dot (the office that sends the folder) and ends at a QR finder
// square (the tagged folder arriving). The route stops at the finder square's ring so the hole stays clean on any
// background. Colours are parameters so every variant comes from the same geometry; `id` keeps masks unique when
// several SVGs are inlined in one page.
function mark({ s, eye, dot }, id) {
  const hole = rr(EX - 33, EY - 33, 66, 66, 12)
  return [
    `<defs><mask id="${id}" maskUnits="userSpaceOnUse" x="0" y="0" width="512" height="512"><rect width="512" height="512" fill="#fff"/><path d="${hole}" fill="#000"/></mask></defs>`,
    `<path d="${S_PATH}" fill="none" stroke="${s}" stroke-width="62" stroke-linecap="round" stroke-linejoin="round" mask="url(#${id})"/>`,
    `<circle cx="156" cy="364" r="46" fill="${dot}"/>`,
    `<path d="${rr(EX - 52, EY - 52, 104, 104, 22)}${hole}" fill="${eye}" fill-rule="evenodd"/>`,
    `<path d="${rr(EX - 17, EY - 17, 34, 34, 7)}" fill="${eye}"/>`,
  ].join('\n  ')
}

const head = (viewBox) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}">`
const write = (name, text) => fs.writeFileSync(path.join(SVG_DIR, name), text.replace(/\r?\n/g, '\n'))

const onNavy = { s: C.white, eye: C.sky, dot: C.gold }
const onLight = { s: C.navy, eye: C.blue, dot: C.gold }
const mono = { s: C.navy, eye: C.navy, dot: C.navy }

// App icons: the mark centred on the brand navy (mark centre is 259,255, so shift it back to 256,256).
const tile = (rx, id) => `${head('0 0 512 512')}
  <title>SmartFlow</title>
  <rect width="512" height="512"${rx ? ` rx="${rx}"` : ''} fill="${C.navy}"/>
  <g transform="translate(-3 1)">
  ${mark(onNavy, id)}
  </g>
</svg>
`
write('smartflow-app-icon.svg', tile(112, 'icon'))
write('smartflow-app-icon-square.svg', tile(0, 'iconsq'))

// Android adaptive icon foreground: transparent, mark inside the 66dp safe circle of a 108dp canvas.
write('smartflow-icon-foreground.svg', `${head('0 0 512 512')}
  <title>SmartFlow</title>
  <g transform="translate(256 256) scale(0.60) translate(-259 -255)">
  ${mark(onNavy, 'fg')}
  </g>
</svg>
`)

// Standalone marks (tight box with a little room).
const markBox = '94 65 330 381'
write('smartflow-mark.svg', `${head(markBox)}\n  <title>SmartFlow</title>\n  ${mark(onLight, 'm1')}\n</svg>\n`)
write('smartflow-mark-light.svg', `${head(markBox)}\n  <title>SmartFlow</title>\n  ${mark(onNavy, 'm2')}\n</svg>\n`)
write('smartflow-mark-mono.svg', `${head(markBox)}\n  <title>SmartFlow</title>\n  ${mark(mono, 'm3')}\n</svg>\n`)

// Horizontal lockup. Text uses the app font with safe fallbacks. On a dark background the mark stands without its tile.
const FONT = "'Source Sans 3','Source Sans Pro','Segoe UI',Arial,sans-serif"
function lockup(dark) {
  const ink = dark ? C.white : C.navy
  const accent = dark ? C.sky : C.blue
  const sub = dark ? '#B9C7DB' : C.slate
  const symbol = dark
    ? `<g transform="translate(24 24) scale(0.5078) translate(-3 1)">\n    ${mark(onNavy, 'ld')}\n  </g>`
    : `<g transform="translate(24 24) scale(0.5078)">\n    <rect width="512" height="512" rx="112" fill="${C.navy}"/>\n    <g transform="translate(-3 1)">\n    ${mark(onNavy, 'll')}\n    </g>\n  </g>`
  return `${head('0 0 1000 300')}
  <title>SmartFlow · Municipality of Urbiztondo</title>
  ${symbol}
  <text x="312" y="168" font-family="${FONT}" font-size="132" font-weight="800" letter-spacing="-2" fill="${ink}">Smart<tspan fill="${accent}">Flow</tspan></text>
  <text x="318" y="228" font-family="${FONT}" font-size="34" font-weight="600" letter-spacing="7" fill="${sub}">MUNICIPALITY OF URBIZTONDO</text>
</svg>
`
}
write('smartflow-logo-horizontal.svg', lockup(false))
write('smartflow-logo-horizontal-dark.svg', lockup(true))
console.log('svg written to', SVG_DIR)
