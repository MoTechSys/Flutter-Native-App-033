import asyncio
from playwright.async_api import async_playwright

URL = 'https://5060-i9f6bive3egfjav2byqbf-5634da27.sandbox.novita.ai/'
W, H = 412, 900
OUT = '/home/user/p1b_'

async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        ctx = await b.new_context(viewport={'width': W, 'height': H}, device_scale_factor=2)
        pg = await ctx.new_page()
        logs = []
        pg.on('console', lambda m: logs.append(f'{m.type}: {m.text}'))
        pg.on('pageerror', lambda e: logs.append(f'PAGEERROR: {e}'))
        await pg.goto(URL, wait_until='load')
        await pg.wait_for_timeout(7000)

        async def shot(name, wait=1500):
            await pg.wait_for_timeout(wait)
            await pg.screenshot(path=OUT + name)

        # Home → tap first avatar in recent row (rightmost, y~830) → new tx for that customer → type step
        await pg.mouse.click(372, 815)
        await shot('20_type_step.png', 2500)
        # "أخذ مني" giant button
        await pg.mouse.click(206, 330)
        await shot('21_amount_empty.png', 2000)
        # tap notes: grid rows; first row y~?; take screenshot first to calibrate then tap
        # Grid starts under segmented button (~y=430). Cells 2 cols, aspect 2.1 → cell h ≈ 190/2.1≈ 86
        for (x, y) in [(300, 470), (300, 470), (110, 470), (300, 565)]:
            await pg.mouse.click(x, y)
            await pg.wait_for_timeout(250)
        await shot('22_amount_notes.png', 800)
        # keypad tab (left segment)
        await pg.mouse.click(120, 405)
        await shot('23_keypad.png', 1000)
        # back to notes tab
        await pg.mouse.click(292, 405)
        await pg.wait_for_timeout(600)
        # confirm button bottom
        await pg.mouse.click(206, 852)
        await shot('24_confirm.png', 2500)
        # save
        await pg.mouse.click(206, 850)
        await shot('25_after_save_undo.png', 1200)
        await shot('26_home_refreshed.png', 8000)
        # Transactions via "الكل"
        await pg.mouse.click(60, 690)
        await shot('27_transactions.png', 2500)
        await pg.mouse.click(206, 190)
        await shot('28_tx_detail.png', 2500)
        # reverse dialog
        await pg.mouse.click(206, 855)
        await shot('29_reverse_dialog.png', 1500)
        await pg.keyboard.type('خطأ في المبلغ')
        await pg.wait_for_timeout(400)
        await pg.screenshot(path=OUT + '29b_reverse_typed.png')
        # confirm button in dialog (left side in RTL, approx)
        await b.close()
        errs = [l for l in logs if 'error' in l.lower() or 'exception' in l.lower()]
        print('\n'.join(errs)[:3000] or 'no errors')

asyncio.run(main())
