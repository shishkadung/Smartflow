import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile, readdir, access } from 'node:fs/promises'

const project = new URL('../../', import.meta.url)
const read = (path) => readFile(new URL(path, project))
const text = async (path) => (await read(path)).toString('utf8')
const exists = (path) => access(new URL(path, project)).then(() => true, () => false)

// Width, height and colour type from a PNG header (colour type 2 = RGB, 6 = RGB with alpha).
async function png(path) {
  const bytes = await read(path)
  assert.equal(bytes.subarray(1, 4).toString('ascii'), 'PNG', `${path} is a PNG`)
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20), colorType: bytes[25] }
}

test('the web page uses the seal icons, not the Vite template icon', async () => {
  const html = await text('web/index.html')
  assert.doesNotMatch(html, /favicon\.svg/)
  for (const file of ['favicon.ico', 'favicon-32.png', 'apple-touch-icon.png', 'manifest.webmanifest']) {
    assert.ok(html.includes(`/${file}`), `index.html links /${file}`)
    assert.ok(await exists(`web/public/${file}`), `web/public/${file} exists`)
  }
  assert.equal(await exists('web/public/favicon.svg'), false)
  const htaccess = await text('web/public/.htaccess')
  for (const file of ['favicon\\.ico', 'apple-touch-icon\\.png', 'icon-192\\.png', 'icon-512\\.png', 'manifest\\.webmanifest']) assert.ok(htaccess.includes(file), `${file} is revalidated on each release`)
})

test('web icon files have the sizes they claim', async () => {
  assert.deepEqual(await png('web/public/favicon-32.png').then(({ width, height }) => [width, height]), [32, 32])
  assert.deepEqual(await png('web/public/apple-touch-icon.png').then(({ width, height }) => [width, height]), [180, 180])
  assert.deepEqual(await png('web/public/icon-192.png').then(({ width, height }) => [width, height]), [192, 192])
  assert.deepEqual(await png('web/public/icon-512.png').then(({ width, height }) => [width, height]), [512, 512])
  const ico = await read('web/public/favicon.ico')
  assert.equal(ico.readUInt16LE(2), 1, 'type is icon')
  const count = ico.readUInt16LE(4)
  const sizes = Array.from({ length: count }, (_, i) => ico[6 + i * 16])
  assert.deepEqual(sizes, [16, 32, 48])
  for (let i = 0; i < count; i++) {
    const length = ico.readUInt32LE(6 + i * 16 + 8)
    const offset = ico.readUInt32LE(6 + i * 16 + 12)
    assert.equal(ico.subarray(offset + 1, offset + 4).toString('ascii'), 'PNG')
    assert.ok(offset + length <= ico.length)
  }
})

test('the web manifest and the Android launcher share one brand colour and one icon design', async () => {
  const manifest = JSON.parse(await text('web/public/manifest.webmanifest'))
  assert.equal(manifest.short_name, 'SmartFlow')
  for (const icon of manifest.icons) assert.ok(await exists(`web/public${icon.src}`), `${icon.src} exists`)
  const background = (await text('mobile/flutter/android/app/src/main/res/values/ic_launcher_background.xml')).match(/#[0-9A-Fa-f]{6}/)?.[0]
  assert.ok(background, 'the Android launcher background colour is set')
  assert.equal(manifest.theme_color.toLowerCase(), background.toLowerCase())
  assert.equal(manifest.background_color.toLowerCase(), background.toLowerCase())
  const html = await text('web/index.html')
  assert.ok(html.toLowerCase().includes(`content="${background.toLowerCase()}"`), 'the page theme colour matches')
})

test('Android launcher icons exist in every density, plus the adaptive icon', async () => {
  const res = 'mobile/flutter/android/app/src/main/res'
  const legacy = { mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 }
  for (const [density, size] of Object.entries(legacy)) {
    const icon = await png(`${res}/mipmap-${density}/ic_launcher.png`)
    assert.deepEqual([icon.width, icon.height], [size, size], `ic_launcher ${density}`)
    const foreground = await png(`${res}/mipmap-${density}/ic_launcher_foreground.png`)
    assert.deepEqual([foreground.width, foreground.height], [size * 2.25, size * 2.25], `foreground ${density} is 108dp`)
  }
  const adaptive = await text(`${res}/mipmap-anydpi-v26/ic_launcher.xml`)
  assert.ok(adaptive.startsWith('<?xml'), 'no byte-order mark before the XML declaration')
  assert.ok((await text(`${res}/values/ic_launcher_background.xml`)).startsWith('<?xml'))
  assert.match(adaptive, /@color\/ic_launcher_background/)
  assert.match(adaptive, /@mipmap\/ic_launcher_foreground/)
  assert.match(await text('mobile/flutter/android/app/src/main/AndroidManifest.xml'), /android:icon="@mipmap\/ic_launcher"/)
})

test('the Android launch screen shows the SmartFlow mark on navy, and the municipal seal stays inside the app', async () => {
  const res = 'mobile/flutter/android/app/src/main/res'
  const density = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 }
  for (const [name, scale] of Object.entries(density)) {
    const logo = await png(`${res}/drawable-${name}/splash_logo.png`)
    assert.deepEqual([logo.width, logo.height], [288 * scale, 288 * scale], `splash_logo ${name} is 288dp`)
  }
  for (const folder of ['values-v31', 'values-night-v31']) {
    const styles = await text(`${res}/${folder}/styles.xml`)
    assert.ok(styles.startsWith('<?xml'), `${folder}: no byte-order mark`)
    assert.match(styles, /android:windowSplashScreenAnimatedIcon">@drawable\/splash_logo</)
    assert.match(styles, /android:windowSplashScreenBackground">@color\/ic_launcher_background</)
  }
  for (const folder of ['drawable', 'drawable-v21']) {
    const launch = await text(`${res}/${folder}/launch_background.xml`)
    assert.match(launch, /@color\/ic_launcher_background/)
    assert.match(launch, /@drawable\/splash_logo/)
  }
  // The in-app loading screen continues the launch screen with the same mark.
  const pubspec = await text('mobile/flutter/pubspec.yaml')
  assert.match(pubspec, /assets\/brand\/smartflow_splash\.png/)
  assert.match(pubspec, /assets\/brand\/urbiztondo_seal\.png/)
  assert.match(await text('mobile/flutter/lib/main.dart'), /assets\/brand\/smartflow_splash\.png/)
  const splash = await png('mobile/flutter/assets/brand/smartflow_splash.png')
  assert.deepEqual([splash.width, splash.height], [512, 591])
  // The municipal seal is untouched: same asset, still used by the app header and the web header.
  assert.ok(await exists('mobile/flutter/assets/brand/urbiztondo_seal.png'))
  assert.match(await text('mobile/flutter/lib/widgets/sf_widgets.dart'), /assets\/brand\/urbiztondo_seal\.png/)
  assert.ok(await exists('web/src/assets/brand/urbiztondo_seal.png'))
})

test('every iOS icon matches its file name and has no alpha channel', async () => {
  const folder = 'mobile/flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset'
  const files = (await readdir(new URL(`${folder}/`, project))).filter((name) => name.endsWith('.png'))
  assert.ok(files.length >= 15)
  for (const name of files) {
    const [, nominal, scale] = name.match(/^Icon-App-([\d.]+)x[\d.]+@(\d)x\.png$/)
    const expected = Math.round(Number(nominal) * Number(scale))
    const icon = await png(`${folder}/${name}`)
    assert.deepEqual([icon.width, icon.height], [expected, expected], name)
    assert.equal(icon.colorType, 2, `${name} is opaque RGB`)
  }
})
