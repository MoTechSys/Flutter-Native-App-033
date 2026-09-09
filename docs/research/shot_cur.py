import asyncio
from playwright.async_api import async_playwright
URL='https://5060-i9f6bive3egfjav2byqbf-5634da27.sandbox.novita.ai/'
OUT='/home/user/cur_'
async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':412,'height':900},device_scale_factor=2)
        pg=await ctx.new_page(); logs=[]
        pg.on('pageerror', lambda e: logs.append(f'PAGEERROR: {e}'))
        await pg.goto(URL+'#/currencies', wait_until='load'); await pg.wait_for_timeout(7000)
        await pg.screenshot(path=OUT+'0.png')
        # SAR card: switch ~ (52,380) ; field ~ (245,425)
        await pg.mouse.click(52,378); await pg.wait_for_timeout(900)
        await pg.screenshot(path=OUT+'1_activated.png')
        await pg.mouse.click(245,425); await pg.wait_for_timeout(600)
        await pg.keyboard.type('140'); await pg.wait_for_timeout(300)
        await pg.screenshot(path=OUT+'2_typing.png')
        await pg.keyboard.press('Enter'); await pg.wait_for_timeout(1500)
        await pg.screenshot(path=OUT+'3_saved.png')
        # documents deep link
        await pg.goto(URL+'#/documents', wait_until='load'); await pg.wait_for_timeout(6000)
        await pg.screenshot(path=OUT+'4_documents.png')
        await pg.mouse.click(40,42); await pg.wait_for_timeout(8000)
        await pg.screenshot(path=OUT+'5_editor.png')
        await pg.goto(URL+'#/settings', wait_until='load'); await pg.wait_for_timeout(6000)
        # toggle dark mode: scroll? dark switch is at y~940 -> scroll
        await pg.mouse.wheel(0,400); await pg.wait_for_timeout(600)
        await pg.screenshot(path=OUT+'6_settings_scrolled.png')
        await b.close(); print('\n'.join(logs)[:2000] or 'no errors')
asyncio.run(main())
