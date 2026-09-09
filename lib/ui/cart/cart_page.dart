// ============================================================
// كِتابي - سلة المشتريات: كمية +/-، حذف، كوبون، ملخص، إتمام الطلب (محاكاة)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../state/store_state.dart';
import '../home/book_detail_page.dart';
import '../orders/order_detail_page.dart';
import '../shared/widgets.dart';
import '../shell.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _coupon = TextEditingController();
  bool _placing = false;

  Future<void> _applyCoupon() async {
    final err = context.read<CartState>().applyCoupon(_coupon.text);
    if (err != null) {
      notify(context, err, error: true);
    } else {
      notify(context, 'تم تطبيق كود الخصم', icon: Icons.local_offer);
      _coupon.clear();
    }
  }

  Future<void> _checkout() async {
    final cart = context.read<CartState>();
    final ok = await confirm(
      context,
      title: 'إتمام الطلب',
      message: 'سيتم تأكيد طلب ${cart.count} كتاب بإجمالي ${fmtPrice(cart.total)}. (محاكاة – لا يوجد دفع فعلي)',
      okLabel: 'تأكيد الطلب',
    );
    if (!ok) return;
    setState(() => _placing = true);
    final order = await cart.checkout();
    if (!mounted) return;
    setState(() => _placing = false);
    notify(context, 'تم تأكيد طلبك رقم #${order.id}', icon: Icons.celebration);
    Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(order: order, justPlaced: true)));
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    return Scaffold(
      appBar: AppBar(
        title: Text('السلة${cart.isEmpty ? '' : ' (${cart.count})'}'),
        actions: [
          if (!cart.isEmpty)
            IconButton(
              tooltip: 'إفراغ السلة',
              icon: const Icon(Icons.remove_shopping_cart_outlined),
              onPressed: () async {
                if (await confirm(context, title: 'إفراغ السلة', message: 'سيتم حذف جميع الكتب من السلة.', okLabel: 'إفراغ', destructive: true)) {
                  await cart.clear();
                  if (context.mounted) notify(context, 'تم إفراغ السلة');
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: cart.isEmpty
            ? EmptyView(
                icon: Icons.shopping_bag_outlined,
                title: 'سلتك فارغة',
                subtitle: 'أضف كتباً من الرئيسية أو التصنيفات لتظهر هنا',
                action: FilledButton.icon(
                  onPressed: () => context.read<ShellController>().go(ShellTab.home),
                  icon: const Icon(Icons.storefront),
                  label: const Text('تصفح الكتب'),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: cart.lines.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _CartTile(line: cart.lines[i]),
                    ),
                  ),
                  _Summary(coupon: _coupon, onApply: _applyCoupon, onCheckout: _placing ? null : _checkout),
                ],
              ),
      ),
    );
  }
}

class _CartTile extends StatelessWidget {
  final CartLine line;
  const _CartTile({required this.line});
  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartState>();
    final b = line.book;
    return Dismissible(
      key: ValueKey('cart-${b.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirm(context, title: 'حذف من السلة', message: 'إزالة "${b.title}" من السلة؟', okLabel: 'حذف', destructive: true),
      onDismissed: (_) async {
        await cart.remove(b);
        if (context.mounted) notify(context, 'أُزيل من السلة');
      },
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: Palette.danger.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: Palette.danger),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: b))),
                child: BookCover(book: b, width: 54, radius: 6, hero: false),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(b.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Palette.ivoryDim, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(fmtPrice(b.price), style: const TextStyle(color: Palette.ivoryDim, fontSize: 12)),
                        const Spacer(),
                        Text(fmtPrice(line.total), style: const TextStyle(color: Palette.gold, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  _RoundBtn(icon: Icons.add, onTap: () => cart.setQty(b, line.qty + 1)),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${line.qty}', style: const TextStyle(fontWeight: FontWeight.w800))),
                  _RoundBtn(
                    icon: line.qty == 1 ? Icons.delete_outline : Icons.remove,
                    danger: line.qty == 1,
                    onTap: () async {
                      if (line.qty == 1) {
                        if (await confirm(context, title: 'حذف من السلة', message: 'إزالة "${b.title}" من السلة؟', okLabel: 'حذف', destructive: true)) {
                          await cart.remove(b);
                          if (context.mounted) notify(context, 'أُزيل من السلة');
                        }
                      } else {
                        cart.setQty(b, line.qty - 1);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  const _RoundBtn({required this.icon, required this.onTap, this.danger = false});
  @override
  Widget build(BuildContext context) => Material(
    color: danger ? Palette.danger.withValues(alpha: 0.15) : Palette.gold.withValues(alpha: 0.15),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 16, color: danger ? Palette.danger : Palette.gold)),
    ),
  );
}

class _Summary extends StatelessWidget {
  final TextEditingController coupon;
  final VoidCallback onApply;
  final VoidCallback? onCheckout;
  const _Summary({required this.coupon, required this.onApply, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        color: Palette.nightSoft,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Palette.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // كوبون
          if (cart.coupon == null)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: coupon,
                    textDirection: TextDirection.ltr,
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => onApply(),
                    decoration: const InputDecoration(hintText: 'كود الخصم (مثال: KITABI10)', prefixIcon: Icon(Icons.local_offer_outlined), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(80, 48)), onPressed: onApply, child: const Text('تطبيق')),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Palette.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Palette.success.withValues(alpha: 0.4))),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Palette.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('كود ${cart.coupon!.code} • خصم ${cart.coupon!.percent}%', style: const TextStyle(color: Palette.success, fontWeight: FontWeight.w600))),
                  IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, size: 18), onPressed: () => context.read<CartState>().removeCoupon()),
                ],
              ),
            ),
          const SizedBox(height: 10),
          _Line('المجموع الفرعي', fmtPrice(cart.subtotal)),
          if (cart.discount > 0) _Line('الخصم', '- ${fmtPrice(cart.discount)}', color: Palette.success),
          const _Line('الشحن', 'مجاني', color: Palette.success),
          const Divider(height: 14),
          Row(
            children: [
              const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              Text(fmtPrice(cart.total), style: const TextStyle(color: Palette.gold, fontWeight: FontWeight.w900, fontSize: 20)),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onCheckout,
            icon: const Icon(Icons.lock_outline),
            label: Text(onCheckout == null ? 'جارٍ التأكيد...' : 'إتمام الطلب'),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String k, v;
  final Color? color;
  const _Line(this.k, this.v, {this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text(k, style: const TextStyle(color: Palette.ivoryDim, fontSize: 13)),
        const Spacer(),
        Text(v, style: TextStyle(color: color ?? Palette.ivory, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
