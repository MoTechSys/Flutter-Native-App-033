import asyncio, sys
from playwright.async_api import async_playwright

URL = 'https://5060-i9f6bive3egfjav2byqbf-5634da27.sandbox.novita.ai/'

async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        ctx = await b.new_context(viewport={'width': 412, 'height': 900}, device_scale_factor=2)
        pg = await ctx.new_page()
        logs = []
        pg.on('console', lambda m: logs.append(f'{m.type}: {m.text}'))
        pg.on('pageerror', lambda e: logs.append(f'PAGEERROR: {e}'))
        await pg.goto(URL, wait_until='networkidle')
        # fresh IndexedDB so demo seed re-runs with photos
        await pg.evaluate("""async () => {
            const dbs = await indexedDB.databases?.() || [];
            for (const d of dbs) { if (d.name) indexedDB.deleteDatabase(d.name); }
            localStorage.clear();
        }""")
        await pg.reload(wait_until='load')
        await pg.wait_for_timeout(7000)
        await pg.screenshot(path='/home/user/shot_home.png')
        # open drawer: hamburger is top-right in RTL
        await pg.mouse.click(412 - 34, 42)
        await pg.wait_for_timeout(1500)
        await pg.screenshot(path='/home/user/shot_drawer.png')
        await b.close()
        errs = [l for l in logs if 'error' in l.lower() or 'exception' in l.lower()]
        print('\n'.join(errs)[:2000] or 'no errors')

asyncio.run(main())
