import asyncio
from playwright.async_api import async_playwright
URL='https://5060-i9f6bive3egfjav2byqbf-5634da27.sandbox.novita.ai/'
async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':412,'height':900},device_scale_factor=2)
        pg=await ctx.new_page(); logs=[]
        pg.on('pageerror', lambda e: logs.append(f'PAGEERROR: {e}'))
        await pg.goto(URL, wait_until='load'); await pg.wait_for_timeout(7000)
        await pg.mouse.click(372,815); await pg.wait_for_timeout(2000)
        await pg.mouse.click(206,330); await pg.wait_for_timeout(2000)
        await pg.screenshot(path='p1c_amount.png')
        # tap 1000 twice, 500 once
        await pg.mouse.click(300,330); await pg.mouse.click(300,330); await pg.mouse.click(110,330); await pg.mouse.click(300,520)
        await pg.wait_for_timeout(700); await pg.screenshot(path='p1c_amount_2500.png')
        # login screen: drawer -> logout not shown for demo (1 user, no pin) so test via 360 width also
        await b.close(); print('\n'.join(logs) or 'no errors')
asyncio.run(main())
