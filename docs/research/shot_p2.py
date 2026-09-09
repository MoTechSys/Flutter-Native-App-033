import asyncio
from playwright.async_api import async_playwright
URL='https://5060-i9f6bive3egfjav2byqbf-5634da27.sandbox.novita.ai/'
OUT='/home/user/p2_'
async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':412,'height':900},device_scale_factor=2)
        pg=await ctx.new_page(); logs=[]
        pg.on('pageerror', lambda e: logs.append(f'PAGEERROR: {e}'))
        pg.on('console', lambda m: logs.append(f'{m.type}: {m.text}') if m.type in ('error',) else None)
        await pg.goto(URL, wait_until='load'); await pg.wait_for_timeout(7000)
        async def shot(n,w=1800):
            await pg.wait_for_timeout(w); await pg.screenshot(path=OUT+n+'.png')
        async def drawer(idx, name):
            # open drawer, tap item idx (header ~170px then 58px rows starting y~190)
            await pg.mouse.click(412-34,42); await pg.wait_for_timeout(900)
            if name=='drawer': await pg.screenshot(path=OUT+'00_drawer.png')
            await pg.mouse.click(300, 215+idx*62); await shot(name, 2200)
        await drawer(3,'01_overdue')
        await pg.go_back(); await pg.wait_for_timeout(800)
        await drawer(4,'02_reports')
        await pg.go_back(); await pg.wait_for_timeout(800)
        await drawer(5,'03_currencies')
        # tap SAR rate field? SAR is inactive; toggle switch at first non-primary card then tap rate
        await pg.go_back(); await pg.wait_for_timeout(800)
        await drawer(6,'04_backup')
        await pg.go_back(); await pg.wait_for_timeout(800)
        await drawer(7,'05_workers')
        await pg.go_back(); await pg.wait_for_timeout(800)
        await drawer(8,'06_settings')
        await pg.go_back(); await pg.wait_for_timeout(800)
        await drawer(9,'07_activation')   # after divider
        await pg.go_back(); await pg.wait_for_timeout(800)
        await drawer(10,'08_voice_help')
        await pg.mouse.click(206,260); await shot('09_voice_help_playing', 1500)
        await pg.go_back(); await pg.wait_for_timeout(800)
        # documents via reports pdf icon
        await drawer(4,'x')
        await pg.mouse.click(40,42); await shot('10_documents',2000)
        await pg.mouse.click(40,42); await shot('11_template_editor',6000)
        await b.close(); print('\n'.join(logs)[:2000] or 'no errors')
asyncio.run(main())
