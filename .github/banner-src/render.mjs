// Banner: `node .github/banner-src/render.mjs`.
// Playwright comes from a sibling infra-site-template clone, which has it for e2e.
import { createRequire } from 'node:module'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const dir = path.dirname(fileURLToPath(import.meta.url))
const assets = path.resolve(dir, '../assets')
const workspace = path.resolve(dir, '../../..')

const require = createRequire(path.join(workspace, 'infra-site-template/package.json'))
const { chromium } = require('playwright')

// The Russian banner is `banner.jpg`, the English one is `banner.en.jpg`
const suffix = { ru: '', en: '.en' }

const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: 2560, height: 960 } })

for (const lang of ['en', 'ru']) {
	await page.goto(`file://${dir}/template.html?lang=${lang}`)
	await page.evaluate(() => document.fonts.ready)
	await page.waitForTimeout(300)
	await page.screenshot({ path: path.join(assets, `banner${suffix[lang]}.jpg`), type: 'jpeg', quality: 92 })
}

await browser.close()
