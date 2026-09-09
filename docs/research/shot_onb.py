import asyncio
from playwright.async_api import async_playwright
URL='https://5060-i9f6bive3egfjav2byqbf-5634da27.sandbox.novita.ai/'
async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':412,'height':900},device_scale_factor=2)
        pg=await ctx.new_page(); logs=[]
        pg.on('pageerror', lambda e: logs.append(f'PAGEERROR: {e}'))
        await pg.goto(URL, wait_until='load'); await pg.wait_for_timeout(2500)
        await pg.evaluate("""async () => { const dbs = await indexedDB.databases?.() || []; for (const d of dbs) { if (d.name) indexedDB.deleteDatabase(d.name); } try{localStorage.clear()}catch(e){} }""")
        await pg.reload(wait_until='load'); await pg.wait_for_timeout(6000)
        await pg.screenshot(path='onb_1.png')
        # shop name field y~530, name y~600, pin y~670
        await pg.mouse.click(206,378); await pg.keyboard.type('بقالة النور')
        await pg.mouse.click(206,440); await pg.keyboard.type('محمد الحاج')
        await pg.mouse.click(206,505); await pg.keyboard.type('1234')
        await pg.wait_for_timeout(500); await pg.screenshot(path='onb_2.png')
        await pg.mouse.click(206,860); await pg.wait_for_timeout(3500)
        await pg.screenshot(path='onb_3_home_empty.png')
        # open drawer, logout (last tile)
        await pg.mouse.click(412-34,42); await pg.wait_for_timeout(1200)
        await pg.screenshot(path='onb_4_drawer.png')
        await b.close(); print('\n'.join(logs) or 'no errors')
asyncio.run(main())
