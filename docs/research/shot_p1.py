import asyncio
from playwright.async_api import async_playwright

URL = 'https://5060-i9f6bive3egfjav2byqbf-5634da27.sandbox.novita.ai/'
W, H = 412, 900
OUT = '/home/user/p1_'

async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        ctx = await b.new_context(viewport={'width': W, 'height': H}, device_scale_factor=2)
        pg = await ctx.new_page()
        logs = []
        pg.on('console', lambda m: logs.append(f'{m.type}: {m.text}'))
        pg.on('pageerror', lambda e: logs.append(f'PAGEERROR: {e}'))
        await pg.goto(URL, wait_until='networkidle')
        await pg.evaluate("""async () => {
            const dbs = await indexedDB.databases?.() || [];
            for (const d of dbs) { if (d.name) indexedDB.deleteDatabase(d.name); }
            localStorage.clear();
        }""")
        await pg.reload(wait_until='load')
        await pg.wait_for_timeout(7000)
        await pg.screenshot(path=OUT + '00_home.png')

        async def shot(name, wait=1500):
            await pg.wait_for_timeout(wait)
            await pg.screenshot(path=OUT + name)

        # 1) Customers quick action (4th card from left in RTL = "الزباين" rightmost)
        # quick action row y ~ 590; rightmost card center x ~ 352
        await pg.mouse.click(352, 595)
        await shot('01_customers_grid.png', 2500)
        # list toggle icon in appbar (RTL: actions on the left) — try x=95,y=50
        await pg.mouse.click(95, 52)
        await shot('02_customers_list.png')
        # open first customer (list row 1 at y~150)
        await pg.mouse.click(206, 150)
        await shot('03_customer_detail.png', 2500)
        # tap "أخذ" action (rightmost of 5 actions row at y~410)
        await pg.mouse.click(372, 405)
        await shot('04_amount_step.png', 2500)
        # tap 1000 note twice, 500 once (grid 2 cols; first row y~560)
        await pg.mouse.click(300, 560)
        await pg.mouse.click(300, 560)
        await pg.mouse.click(110, 560)
        await shot('05_amount_2500.png', 800)
        # confirm (bottom button y~855)
        await pg.mouse.click(206, 855)
        await shot('06_confirm.png', 2500)
        # save
        await pg.mouse.click(206, 855)
        await shot('07_detail_after_save_undo.png', 2500)
        # back to customers, then home
        await pg.go_back(); await pg.wait_for_timeout(1200)
        await pg.go_back(); await pg.wait_for_timeout(1500)
        await pg.screenshot(path=OUT + '08_home_after.png')
        # transactions list via "الكل" (left of آخر الحركات header y~690, x~60)
        await pg.mouse.click(60, 690)
        await shot('09_transactions.png', 2500)
        # open first tx row (y~190)
        await pg.mouse.click(206, 190)
        await shot('10_tx_detail.png', 2500)
        await pg.go_back(); await pg.wait_for_timeout(1000)
        await pg.go_back(); await pg.wait_for_timeout(1200)
        # new transaction from center quick action -> step1 pick customer
        await pg.mouse.click(258, 595)
        await shot('11_pick_customer.png', 2500)
        await pg.mouse.click(352, 170)  # first grid tile
        await shot('12_type_step.png', 2500)
        await pg.go_back(); await pg.wait_for_timeout(800)
        await pg.go_back(); await pg.wait_for_timeout(800)
        await pg.go_back(); await pg.wait_for_timeout(800)
        # drawer -> logout not implemented; test login screen by clearing session key
        await pg.evaluate("localStorage.removeItem('flutter.session.user_id')")
        await pg.reload(wait_until='load')
        await pg.wait_for_timeout(6000)
        await pg.screenshot(path=OUT + '13_login.png')
        await b.close()
        errs = [l for l in logs if 'error' in l.lower() or 'exception' in l.lower()]
        print('\n'.join(errs)[:3000] or 'no errors')

asyncio.run(main())
